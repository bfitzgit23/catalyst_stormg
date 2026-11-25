#!/usr/bin/env python3
"""stormos-installerd — StormOS installer backend.

Stdlib only, loopback only, runs as root. The browser never executes a privileged
command: it sends a plan, gets it validated, and streams progress from here.

Endpoints:
  GET  /api/health      liveness
  GET  /api/overview    disks,EFI,live source,locale/keymap/timezone choices
  GET  /api/disks       lsblk JSON normalized for the UI
  POST /api/validate    {plan} -> {ok, errors, warnings}
  POST /api/install     {plan} -> {id} (starts worker thread)
  GET  /api/events      SSE stream of progress events
  GET  /api/log         last 200 log lines
  POST /api/cancel      request cancellation
  POST /api/command     {action} -> reboot|poweroff (allow-listed)

Safety: the disk hosting the running ISO is refused, destructive plans need an
explicit confirmation token, and no shell=True is used anywhere.
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import re
import shutil
import subprocess
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse
from uuid import uuid4

BIND = "127.0.0.1"
MOUNT = "/mnt"
SFS_MOUNT = "/tmp/stormos-install-sfs"
FRONTEND = Path(__file__).resolve().parent.parent / "frontend"

# Distro-specific commands and media layout. Arch defaults are kept in code so
# the same backend runs unchanged there; the Gentoo live image ships profile.json.
PROFILE_PATH = Path(__file__).resolve().with_name("profile.json")
try:
    PROFILE = json.loads(PROFILE_PATH.read_text(encoding="utf-8"))
except Exception:
    PROFILE = {}
SFS_GLOBS = PROFILE.get("sfs_globs", (
    "/run/archiso/copytoram/airootfs.sfs",
    "/run/archiso/bootmnt/arch/x86_64/airootfs.sfs",
))
CHROOT_PREFIX = PROFILE.get("chroot_cmd", ["arch-chroot", MOUNT])

LOCALES = {
    "en_US.UTF-8": "en_US.UTF-8 UTF-8",
    "en_GB.UTF-8": "en_GB.UTF-8 UTF-8",
    "de_DE.UTF-8": "de_DE.UTF-8 UTF-8",
    "fr_FR.UTF-8": "fr_FR.UTF-8 UTF-8",
    "es_ES.UTF-8": "es_ES.UTF-8 UTF-8",
    "pt_BR.UTF-8": "pt_BR.UTF-8 UTF-8",
    "ru_RU.UTF-8": "ru_RU.UTF-8 UTF-8",
    "zh_CN.UTF-8": "zh_CN.UTF-8 UTF-8",
    "ja_JP.UTF-8": "ja_JP.UTF-8 UTF-8",
}
FILESystems = ("ext4", "btrfs", "xfs")
MODES = ("erase", "manual")
STEPS = (
    ("preflight", 5),
    ("partition", 10),
    ("format", 10),
    ("mount", 8),
    ("unpack", 35),
    ("fstab", 4),
    ("configure", 16),
    ("bootloader", 10),
    ("finish", 2),
)

FS_COMMANDS = {
    "ext4": ["mkfs.ext4", "-F", "-L", "STORMROOT"],
    "btrfs": ["mkfs.btrfs", "-f", "-L", "STORMROOT"],
    "xfs": ["mkfs.xfs", "-f", "-L", "STORMROOT"],
}

STATE = {
    "token": uuid4().hex[:8].upper(),
    "running": False,
    "cancel": False,
    "plan": None,
    "events": [],
    "log": [],
    "stream_done": False,
}
LOCK = threading.Lock()
COND = threading.Condition(LOCK)


def command(argv: list[str], *, check: bool = True, timeout: int | None = None,
            stdin: str | None = None) -> str:
    """Run an argv list (never a shell string) and return combined output."""
    result = subprocess.run(
        [str(part) for part in argv],
        input=stdin,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        check=check,
        timeout=timeout,
    )
    return result.stdout or ""


def emit(kind: str, payload: dict) -> None:
    event = {"kind": kind, "ts": round(time.time(), 3), **payload}
    with COND:
        STATE["events"].append(event)
        if kind in ("done", "error"):
            STATE["stream_done"] = True
        STATE["log"].append(json.dumps(event, separators=(",", ":")))
        if len(STATE["log"]) > 500:
            STATE["log"].pop(0)
        COND.notify_all()


def disk_of(source: str) -> str | None:
    """Map a mounted device (or partition) back to its parent disk."""
    name = os.path.basename(source.strip())
    if not name or name.startswith("loop") or name in ("overlay", "tmpfs"):
        return None
    if name.startswith(("nvme", "mmcblk")):
        base = re.sub(r"p\d+$", "", name)
    else:
        base = re.sub(r"\d+$", "", name)
    if not base:
        return None
    device = "/dev/" + base
    return device if Path(device).exists() else None


def live_disks() -> set[str]:
    found: set[str] = set()
    for target in ("/", "/run/archiso/bootmnt", "/run/archiso/copytoram"):
        try:
            source = command(["findmnt", "-no", "SOURCE", target], check=False).strip()
        except Exception:
            continue
        if not source or source.startswith("/dev/loop"):
            continue
        disk = disk_of(source)
        if disk:
            found.add(disk)
    for candidate in Path("/sys/class/block").glob("loop*/loop/backing_file"):
        try:
            backing = candidate.read_text().strip()
        except OSError:
            continue
        if "airootfs.sfs" in backing:
            disk = disk_of(backing)
            if disk:
                found.add(disk)
    return found


def partition_name(disk: str, number: int) -> str:
    base = os.path.basename(disk)
    return f"/dev/{base}p{number}" if base.startswith(("nvme", "mmcblk")) else f"/dev/{base}{number}"


def disks() -> list[dict]:
    try:
        raw = command(["lsblk", "-J", "-b", "-o",
                       "NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL,RM,PKNAME"])
        data = json.loads(raw)
    except Exception as exc:
        emit("error", {"message": f"lsblk failed: {exc}"})
        return []
    live = live_disks()
    result = []
    for block in data.get("blockdevices", []):
        if block.get("type") != "disk":
            continue
        name = "/dev/" + block["name"]
        children = [
            {
                "name": "/dev/" + child["name"],
                "size": int(child.get("size") or 0),
                "fstype": child.get("fstype") or "",
                "mount": child.get("mountpoint") or "",
            }
            for child in (block.get("children") or [])
            if child.get("type") == "part"
        ]
        result.append({
            "name": name,
            "size": int(block.get("size") or 0),
            "model": (block.get("model") or "").strip(),
            "removable": bool(block.get("rm")),
            "partitions": children,
            "live": name in live,
        })
    return sorted(result, key=lambda item: (-item["size"], item["name"]))


def keymaps() -> list[str]:
    try:
        return [line.strip() for line in command(
            ["localectl", "list-keymaps"], check=False).splitlines() if line.strip()]
    except Exception:
        return ["us"]


def timezones() -> list[str]:
    zoneinfo = Path("/usr/share/zoneinfo")
    common = ["UTC", "America/New_York", "America/Chicago", "America/Denver",
              "America/Los_Angeles", "America/Sao_Paulo", "Europe/London",
              "Europe/Berlin", "Europe/Paris", "Asia/Tokyo", "Asia/Shanghai",
              "Australia/Sydney"]
    return [tz for tz in common if (zoneinfo / tz).is_file()]


def overview() -> dict:
    efi = Path("/sys/firmware/efi").is_dir()
    source = ""
    for candidate in ("/run/archiso/copytoram/airootfs.sfs",
                      "/run/archiso/bootmnt/arch/x86_64/airootfs.sfs"):
        if Path(candidate).is_file():
            source = candidate
            break
    return {
        "efi": efi,
        "source": source,
        "live_disks": sorted(live_disks()),
        "disks": disks(),
        "token": STATE["token"],
        "locales": sorted(LOCALES),
        "keymaps": keymaps(),
        "timezones": timezones(),
        "bootloaders": ["grub"],
        "memory_mb": int((os.sysconf("SC_PAGE_SIZE") * os.sysconf("SC_AVPHYS_PAGES")) // 1048576),
        "running": STATE["running"],
    }


def validate(plan: dict, check_confirm: bool = True) -> dict:
    errors: list[str] = []
    warnings: list[str] = []
    mode = plan.get("mode")
    if mode not in MODES:
        errors.append("Choose a valid installation mode")

    disk = str(plan.get("disk") or "")
    if mode == "erase":
        if not disk.startswith("/dev/") or not Path(disk).exists():
            errors.append("Choose an existing destination disk")
        elif disk in live_disks():
            errors.append("That disk is running the live ISO and cannot be erased")
        else:
            size = int(plan.get("disk_size") or 0)
            if size and size < 20 * 1024**3:
                errors.append("Destination disk must be at least 20 GB")
            warnings.append("All data on the destination disk will be destroyed")
    elif mode == "manual":
        root = str(plan.get("root_part") or "")
        if not root.startswith("/dev/") or not Path(root).exists():
            errors.append("Choose an existing root partition")
        esp = str(plan.get("esp_part") or "")
        if esp:
            if not esp.startswith("/dev/") or not Path(esp).exists():
                errors.append("EFI system partition does not exist")
            if plan.get("boot") != "uefi":
                warnings.append("An EFI partition was selected but BIOS boot is active")
        if plan.get("boot") == "uefi" and not esp:
            errors.append("EFI boot requires an EFI system partition")

    if plan.get("boot") not in ("uefi", "bios"):
        errors.append("Boot mode could not be determined")
    if plan.get("fs") not in FILESystems:
        errors.append("Choose ext4, btrfs or xfs")
    if plan.get("locale") not in LOCALES:
        errors.append("Choose a supported locale")
    if plan.get("keymap") not in keymaps():
        errors.append("Choose a valid keyboard layout")
    if plan.get("timezone") not in timezones():
        errors.append("Choose a valid timezone")

    username = str(plan.get("username") or "")
    if not re.fullmatch(r"[a-z_][a-z0-9_-]{0,31}", username):
        errors.append("Username must start with a letter, 2-32 lowercase characters")
    password = str(plan.get("password") or "")
    if len(password) < 8:
        errors.append("Password must be at least 8 characters")
    hostname = str(plan.get("hostname") or "")
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9-]{0,62}", hostname):
        errors.append("Hostname contains invalid characters")
    if check_confirm and str(plan.get("confirm") or "").strip() != STATE["token"]:
        errors.append("Confirmation token does not match")

    if STATE["running"]:
        errors.append("An installation is already running")
    return {"ok": not errors, "errors": errors, "warnings": warnings, "plan": plan}


def sfs_source() -> str:
    for pattern in SFS_GLOBS:
        matches = sorted(glob.glob(pattern, recursive=True))
        for candidate in matches:
            if Path(candidate).is_file():
                return candidate
    raise RuntimeError("live squashfs not found")


def umount_all() -> None:
    for target in (SFS_MOUNT, MOUNT):
        if Path(target).exists():
            command(["umount", "-R", target], check=False)


def chroot(argv: list[str], *, stdin: str | None = None) -> str:
    return command([*CHROOT_PREFIX, *argv], stdin=stdin)


def generate_fstab() -> str:
    """Write /etc/fstab; used when the distro has no genfstab (e.g. Gentoo)."""
    lines = ["# Generated by the StormOS installer", ""]
    try:
        mounts = command(
            ["findmnt", "-rno", "SOURCE,FSTYPE,TARGET", "-R", MOUNT], check=False
        )
    except Exception:
        mounts = ""
    for line in mounts.splitlines():
        parts = line.split()
        if len(parts) < 3:
            continue
        source, fstype, target = parts[0], parts[1], parts[2]
        if not source.startswith("/dev/"):
            continue
        rel = "/" if target == MOUNT else target[len(MOUNT):]
        try:
            uuid = command(["lsblk", "-no", "UUID", source], check=False).strip()
        except Exception:
            uuid = ""
        token = f"UUID={uuid}" if uuid else source
        passno = "1" if rel == "/" else "2"
        lines.append(f"{token}  {rel}  {fstype}  defaults  0 {passno}")
    return "\n".join(lines) + "\n"


def configure(plan: dict) -> None:
    user = plan["username"]
    password = plan["password"]
    locale_line = LOCALES[plan["locale"]]
    hostname = plan["hostname"]

    secret = Path(MOUNT) / "root" / ".storm-install-passwd"
    secret.write_text(f"{user}:{password}\n", encoding="utf-8")
    secret.chmod(0o600)

    script = f"""set -eu
ln -sf /usr/share/zoneinfo/{plan['timezone']} /etc/localtime
hwclock --systohc 2>/dev/null || true
grep -q '^{re.escape(locale_line)}' /etc/locale.gen || printf '{locale_line}\\n' >> /etc/locale.gen
sed -i 's/^# *{re.escape(locale_line)}/{locale_line}/' /etc/locale.gen
locale-gen
printf 'LANG={plan['locale']}\\n' > /etc/locale.conf
printf 'KEYMAP={plan['keymap']}\\n' > /etc/vconsole.conf
printf '{hostname}\\n' > /etc/hostname
printf '127.0.0.1 localhost\\n::1 localhost\\n127.0.1.1 {hostname}\\n' > /etc/hosts
groupadd -r autologin 2>/dev/null || true
useradd -m -G wheel,autologin,audio,video,network,storage,optical,power -s /bin/bash {user} 2>/dev/null || true
chpasswd < /root/.storm-install-passwd
rm -f /root/.storm-install-passwd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
sed -i '/^\\[Seat:\\*\\]/a autologin-user={user}' /etc/lightdm/lightdm.conf 2>/dev/null || true
if command -v systemctl >/dev/null 2>&1; then systemctl enable NetworkManager.service lightdm.service 2>/dev/null || true; else rc-update add NetworkManager default 2>/dev/null || true; rc-update add lightdm default 2>/dev/null || true; fi
if [ -x /usr/local/bin/postinstall.sh ]; then CALAMARES_TARGET_ROOT=/ /usr/local/bin/postinstall.sh; fi
if [ -x /usr/local/bin/aetherde-postinstall.sh ]; then CALAMARES_TARGET_ROOT=/ /usr/local/bin/aetherde-postinstall.sh; fi
mkinitcpio -P
"""
    chroot(["/bin/bash", "-c", script])
    secret.unlink(missing_ok=True)


def install_worker(plan: dict) -> None:
    progress = 0
    try:
        mode = plan["mode"]
        boot = plan["boot"]
        efi = boot == "uefi"
        disk = plan["disk"]
        root_part = ""
        esp_part = ""

        emit("step", {"name": "preflight", "status": "running", "progress": progress})
        umount_all()
        if mode == "erase" and disk in live_disks():
            raise RuntimeError("refusing to erase the live ISO disk")
        progress += dict(STEPS)["preflight"]
        emit("step", {"name": "preflight", "status": "done", "progress": progress})

        if mode == "erase":
            emit("step", {"name": "partition", "status": "running", "progress": progress})
            if efi:
                command(["sgdisk", "-o",
                         "-n", "1:0:+512M", "-t", "1:ef00",
                         "-n", "2:0:0", "-t", "2:8300", disk])
            else:
                command(["sgdisk", "-o",
                         "-n", "1:0:+1M", "-t", "1:ef02",
                         "-n", "2:0:0", "-t", "2:8300", disk])
            command(["partprobe", disk])
            esp_part, root_part = partition_name(disk, 1 if efi else 1), partition_name(disk, 2 if efi else 2)
            if not efi:
                esp_part = ""
            progress += dict(STEPS)["partition"]
            emit("step", {"name": "partition", "status": "done", "progress": progress})
        else:
            root_part = plan["root_part"]
            esp_part = plan.get("esp_part") if efi else ""
            for name, weight in (("partition", 10), ("format", 10)):
                emit("step", {"name": name, "status": "skip", "progress": progress})
                progress += weight

        if mode == "erase":
            emit("step", {"name": "format", "status": "running", "progress": progress})
            if efi:
                command(["mkfs.vfat", "-F32", "-n", "STORMBOOT", esp_part])
            command([*FS_COMMANDS[plan["fs"]], root_part])
            progress += dict(STEPS)["format"]
            emit("step", {"name": "format", "status": "done", "progress": progress})

        emit("step", {"name": "mount", "status": "running", "progress": progress})
        Path(MOUNT).mkdir(parents=True, exist_ok=True)
        command(["mount", root_part, MOUNT])
        if efi and esp_part:
            Path(MOUNT, "boot").mkdir(parents=True, exist_ok=True)
            command(["mount", esp_part, str(Path(MOUNT, "boot"))])
        progress += dict(STEPS)["mount"]
        emit("step", {"name": "mount", "status": "done", "progress": progress})

        emit("step", {"name": "unpack", "status": "running", "progress": progress})
        Path(SFS_MOUNT).mkdir(parents=True, exist_ok=True)
        command(["mount", "-o", "loop,ro", sfs_source(), SFS_MOUNT])
        command(["rsync", "-aHAX", "--numeric-ids", "--info=progress2",
                 SFS_MOUNT + "/", MOUNT + "/"])
        progress += dict(STEPS)["unpack"]
        emit("step", {"name": "unpack", "status": "done", "progress": progress})

        emit("step", {"name": "fstab", "status": "running", "progress": progress})
        if PROFILE.get("fstab") == "internal":
            fstab = generate_fstab()
        else:
            fstab = command(["genfstab", "-U", MOUNT])
        Path(MOUNT, "etc", "fstab").write_text(fstab, encoding="utf-8")
        progress += dict(STEPS)["fstab"]
        emit("step", {"name": "fstab", "status": "done", "progress": progress})

        emit("step", {"name": "configure", "status": "running", "progress": progress})
        configure(plan)
        progress += dict(STEPS)["configure"]
        emit("step", {"name": "configure", "status": "done", "progress": progress})

        emit("step", {"name": "bootloader", "status": "running", "progress": progress})
        if efi:
            chroot(["grub-install", "--target=x86_64-efi", "--efi-directory=/boot",
                    "--bootloader-id=StormOS"])
        else:
            chroot(["grub-install", "--target=i386-pc", disk])
        chroot(["grub-mkconfig", "-o", "/boot/grub/grub.cfg"])
        progress += dict(STEPS)["bootloader"]
        emit("step", {"name": "bootloader", "status": "done", "progress": progress})

        emit("step", {"name": "finish", "status": "running", "progress": progress})
        emit("done", {"progress": 100, "message": "Installation complete"})
        progress += dict(STEPS)["finish"]
    except Exception as exc:
        emit("error", {"progress": progress, "message": str(exc)})
    finally:
        umount_all()
        with COND:
            STATE["running"] = False
            STATE["cancel"] = False
            COND.notify_all()


class Handler(BaseHTTPRequestHandler):
    server_version = "StormInstaller/1.0"

    def log_message(self, *_args: object) -> None:
        pass

    def _send(self, payload: object, code: int = 200) -> None:
        body = json.dumps(payload, separators=(",", ":")).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _body(self) -> dict:
        length = int(self.headers.get("Content-Length") or 0)
        if not length:
            return {}
        try:
            return json.loads(self.rfile.read(length).decode("utf-8"))
        except (ValueError, UnicodeDecodeError):
            return {}

    def _static(self, name: str) -> None:
        target = (FRONTEND / name).resolve()
        if target.parent != FRONTEND or not target.is_file():
            self._send({"error": "not found"}, 404)
            return
        media = "text/html" if name.endswith(".html") else (
            "text/css" if name.endswith(".css") else "application/javascript"
        )
        body = target.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", f"{media}; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _events(self) -> None:
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream; charset=utf-8")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "keep-alive")
        self.end_headers()
        index = 0
        try:
            while True:
                with COND:
                    while index >= len(STATE["events"]) and not STATE["stream_done"]:
                        COND.wait(timeout=10)
                        self.wfile.write(b": keepalive\n\n")
                        self.wfile.flush()
                    if index >= len(STATE["events"]):
                        break
                    event = STATE["events"][index]
                    index += 1
                frame = "data: " + json.dumps(event, separators=(",", ":")) + "\n\n"
                self.wfile.write(frame.encode("utf-8"))
                self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError, OSError):
            return

    def do_GET(self) -> None:
        path = urlparse(self.path).path
        if path == "/api/health":
            self._send({"ok": True, "service": "stormos-installerd", "running": STATE["running"]})
        elif path == "/api/overview":
            self._send(overview())
        elif path == "/api/disks":
            self._send({"disks": disks(), "live": sorted(live_disks())})
        elif path == "/api/events":
            self._events()
        elif path == "/api/log":
            with LOCK:
                self._send({"lines": list(STATE["log"][-200:])})
        elif path in ("/", "/index.html"):
            self._static("index.html")
        elif path in ("/styles.css", "/renderer.js"):
            self._static(path.lstrip("/"))
        else:
            self._send({"error": "not found"}, 404)

    def do_POST(self) -> None:
        path = urlparse(self.path).path
        body = self._body()
        if path == "/api/validate":
            self._send(validate(
                body.get("plan") or {},
                check_confirm=bool(body.get("check_confirm", True)),
            ))
        elif path == "/api/install":
            verdict = validate(body.get("plan") or {})
            if not verdict["ok"]:
                self._send(verdict, 400)
                return
            with COND:
                if STATE["running"]:
                    self._send({"error": "install already running"}, 409)
                    return
                STATE["plan"] = verdict["plan"]
                STATE["running"] = True
                STATE["cancel"] = False
                STATE["events"] = []
                STATE["log"] = []
                STATE["stream_done"] = False
            threading.Thread(target=install_worker, args=(verdict["plan"],),
                             name="stormos-install", daemon=True).start()
            self._send({"ok": True, "id": uuid4().hex})
        elif path == "/api/cancel":
            with COND:
                STATE["cancel"] = True
            self._send({"ok": True})
        elif path == "/api/command":
            actions = {"reboot": ["systemctl", "reboot"],
                       "poweroff": ["systemctl", "poweroff"]}
            argv = actions.get(str(body.get("action")))
            if not argv:
                self._send({"error": "unknown command"}, 400)
                return
            threading.Thread(target=command, args=(argv,), kwargs={"check": False},
                             daemon=True).start()
            self._send({"ok": True})
        else:
            self._send({"error": "not found"}, 404)


def main() -> None:
    parser = argparse.ArgumentParser(prog="stormos-installerd")
    parser.add_argument("--port", type=int, default=9877)
    options = parser.parse_args()
    if os.geteuid() != 0:
        raise SystemExit("stormos-installerd must run as root")
    server = ThreadingHTTPServer((BIND, options.port), Handler)
    server.daemon_threads = True
    print(f"stormos-installerd listening on http://{BIND}:{options.port}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
