#!/usr/bin/env bash
#
# autocatalyst.sh
#
# One-shot, location-independent builder for the StormG live GUI ISO.
#
# The catalyst build is normally tied to a hardcoded build box path
# (/home/bennji/Desktop/catalyst_stormg/...) baked into the *.spec files.
# This script de-hardcodes that: it rewrites a copy of the specs to point at
# wherever the repo actually lives, so the build can be run from ANY Gentoo
# system - including a box booted from a live GUI ISO - and from any checkout
# directory.
#
# NOTE on other distros (Arch/Ubuntu/...):
#   catalyst drives Portage (emerge) and a stage3 chroot; it cannot run
#   natively outside Gentoo. The supported way to build on another distro is to
#   run THIS script inside a Gentoo container. See README "Building on other
#   distros" - docker/podman one-liner is provided there.
#
# Usage:
#   sudo ./autocatalyst.sh [--only stage1|stage2] [--stage3 <url>] [--snapshot <ref>]
#                          [-j <jobs>] [--keep] [--dry-run]
#
# Env overrides:
#   REPO_DIR       repo root   (default: directory containing this script)
#   WORKDIR        build work  (default: $REPO_DIR/build)
#   STAGE3_URL     stage3 tarball URL (else auto-detect latest)
#   --snapshot REF uses a specific gentoo treeish (default: fresh HEAD)
#   CATALYST_JOBS  make jobs (default: nproc)
#   CATALYST_OPTS  extra args passed to catalyst
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="${REPO_DIR:-$SCRIPT_DIR}"
WORKDIR="${WORKDIR:-$REPO_DIR/build}"
SPEC_S1="$REPO_DIR/livegui-stage1.spec"
SPEC_S2="$REPO_DIR/livegui-stage2.spec"
FSS="$REPO_DIR/stage2.sh"
ROOT_OVL="$REPO_DIR/root_overlay"
OVERLAY_DIR="$REPO_DIR/overlay"
PORTAGE_CONFD="$REPO_DIR/config/stages"
CONF_STAGE1="$WORKDIR/livegui-stage1.spec"
CONF_STAGE2="$WORKDIR/livegui-stage2.spec"
CATALYST_CONF="$WORKDIR/catalyst.conf"
STAGE3_RELDIR="23.0-default/stage3-amd64-desktop-openrc-latest.tar.xz"

OLD_PREFIX='/home/bennji/Desktop/catalyst_stormg'
# Where to save the finished ISO (a mounted Windows data partition). Override
# with $WINDRIVE or --windrive.
WINDRIVE="${WINDRIVE:-/run/media/calamaroos/B0327A2D3279FB8A4}"
ONLY='all'
DRY=0
JOBS="${CATALYST_JOBS:-$(nproc)}"
SNAP_REF=""            # resolved below: SHA of the fresh gentoo tree (or --snapshot override)
SNAP_REF_EXPLICIT=0
GENTOO_REPO="https://github.com/gentoo/gentoo"
GURU_REPO="https://github.com/gentoo-mirror/guru"
STEAM_REPO="https://github.com/anyc/steam-overlay"

# --------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------
_info(){ printf '\033[34m[*]\033[0m %s\n' "$*"; }
_ok(){   printf '\033[32m[+]\033[0m %s\n' "$*"; }
_warn(){ printf '\033[33m[!]\033[0m %s\n' "$*" >&2; }
_die(){  printf '\033[31m[!]\033[0m %s\n' "$*" >&2; exit 1; }
_have(){ command -v "$1" >/dev/null 2>&1; }

_run(){
  if [ "$DRY" -eq 1 ]; then
    _info "[dry-run] $*"
  else
    "$@"
  fi
}

usage(){ sed -n '1,40p' "$0" | grep -E '^#|Usage' | sed 's/^# \{0,1\}//'; }

COPY_OK=0
# Copy any finished ISO to the Windows drive so it survives the cleanup below.
_copy_iso(){
  local found
  found="$(find "$WORKDIR" -maxdepth 3 -name '*.iso' -print -quit 2>/dev/null)"
  if [ -z "$found" ]; then
    _warn "No ISO built yet; nothing to save."
    return 0
  fi
  if [ "$DRY" -eq 1 ]; then _info "[dry-run] cp $found $WINDRIVE/"; return 0; fi
  if ! mkdir -p "$WINDRIVE" 2>/dev/null; then
    _warn "Cannot access Windows drive '$WINDRIVE' (not mounted?)."
    return 0
  fi
  if cp -f "$found" "$WINDRIVE/" 2>/dev/null; then
    _ok "ISO saved to $WINDRIVE/$(basename "$found")"
    COPY_OK=1
  else
    _warn "Failed to copy ISO to '$WINDRIVE'"
  fi
}
# On success OR failure: save the ISO to the Windows drive, then remove the
# build dir (unless --keep). Never delete a real ISO we couldn't save.
_cleanup(){
  local rc=$?
  local iso
  _copy_iso
  iso="$(find "$WORKDIR" -maxdepth 3 -name '*.iso' -print -quit 2>/dev/null)"
  if [ -n "${KEEP:-}" ] && [ -d "$WORKDIR" ]; then
    _warn "--keep set; build dir retained: $WORKDIR"
  elif [ -n "$iso" ] && [ "$COPY_OK" -eq 0 ] && [ "$DRY" -eq 0 ]; then
    _warn "ISO present but could not be copied to '$WINDRIVE'; keeping build dir."
  else
    [ -d "$WORKDIR" ] && { _info "Removing build dir: $WORKDIR"; rm -rf "$WORKDIR"; }
  fi
  return "$rc"
}

# --------------------------------------------------------------------------
# arg parsing
# --------------------------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --only=*)            ONLY="${1#*=}" ;;
    --stage3=*)          STAGE3_URL="${1#*=}" ;;
    --windrive=*)       WINDRIVE="${1#*=}" ;;
    --snapshot=*)        SNAP_REF="${1#*=}"; SNAP_REF_EXPLICIT=1 ;;
    --keep)              KEEP=1 ;;
    --dry-run)           DRY=1 ;;
    -j)                  JOBS="$2"; shift ;;
    --jobs=*)            JOBS="${1#*=}" ;;
    -h|--help)           usage; exit 0 ;;
    *)                   _warn "Ignoring unknown argument: $1" ;;
  esac
  shift
done

[ "$(id -u)" -eq 0 ] || _die "Run with sudo/root (catalyst needs it)."
case "$ONLY" in all|stage1|stage2) ;; *) _die "Bad --only value: $ONLY (all|stage1|stage2)" ;; esac
[ -f "$SPEC_S1" ] || _die "Missing $SPEC_S1"
[ -f "$SPEC_S2" ] || _die "Missing $SPEC_S2"
[ -f "$FSS" ]     || _die "Missing $FSS"

# --------------------------------------------------------------------------
# 1. de-hardcode the specs into $WORKDIR
# --------------------------------------------------------------------------
_write_specs(){
  _info "Rewriting hardcoded '$OLD_PREFIX' -> '$REPO_DIR' in spec copies"
  mkdir -p "$WORKDIR"
  local esc escw
  esc="$(printf '%s' "$REPO_DIR"  | sed 's/[\\&]/\\&/g')"
  escw="$(printf '%s' "$WORKDIR"  | sed 's/[\\&]/\\&/g')"
  for pair in "$SPEC_S1:$CONF_STAGE1" "$SPEC_S2:$CONF_STAGE2"; do
    local src="${pair%%:*}" dst="${pair#*:}"
    sed -e "s#${OLD_PREFIX}#${esc}#g" \
        -e "s#${esc}/overlay/var/db/repos/gentoo#${escw}/repos/gentoo#g" \
        -e "s#${esc}/overlay/var/db/repos/guru#${escw}/repos/guru#g" \
        -e "s#${esc}/overlay/var/db/repos/steam-overlay#${escw}/repos/steam-overlay#g" \
        -e "s#^snapshot_treeish:.*#snapshot_treeish: ${SNAP_REF:-HEAD}#" \
        "$src" > "$dst"
  done
  _ok "specs written (fresh git repos + treeish ${SNAP_REF:-HEAD})"
}

# --------------------------------------------------------------------------
# 2. snapshot - FRESH git sync (no reliance on the bundled, stale overlay tree)
# --------------------------------------------------------------------------
_fresh_sync(){
  _info "Fresh-syncing the gentoo tree + overlay repos"
  mkdir -p "$WORKDIR/repos"

  if [ ! -d "$WORKDIR/repos/gentoo/.git" ]; then
    _info "cloning gentoo ..."
    _run git clone --quiet --filter=blob:none "$GENTOO_REPO" "$WORKDIR/repos/gentoo"
  else
    _ok "gentoo clone present; pulling"
    _run git -C "$WORKDIR/repos/gentoo" pull --ff-only
  fi
  for pair in "guru:$GURU_REPO" "steam-overlay:$STEAM_REPO"; do
    local name="${pair%%:*}" url="${pair#*:}"
    if [ ! -d "$WORKDIR/repos/$name/.git" ]; then
      _info "cloning $name ..."
      _run git clone --quiet "$url" "$WORKDIR/repos/$name"
    else
      _run git -C "$WORKDIR/repos/$name" pull --ff-only
    fi
  done

if [ "$SNAP_REF_EXPLICIT" -eq 0 ]; then
    SNAP_REF="$(git -C "$WORKDIR/repos/gentoo" rev-parse --short=12 HEAD 2>/dev/null || echo HEAD)"
  fi
  _ok "snapshot will be built from gentoo treeish ${SNAP_REF}"
}

# --------------------------------------------------------------------------
# 3. stage3 tarball
# --------------------------------------------------------------------------
_ensure_stage3(){
  if [ "$DRY" -eq 1 ]; then _info "skipping stage3 fetch (dry-run)"; return; fi
  local dist="$WORKDIR/distfiles"
  local out="$dist/$STAGE3_RELDIR"
  local url
  mkdir -p "$(dirname "$out")"

  if [ -s "$out" ]; then
    _ok "stage3 already downloaded, reusing: $out"
    return
  fi

  if [ -n "${STAGE3_URL:-}" ]; then
    url="$STAGE3_URL"
    _info "Using stage3 from \$STAGE3_URL"
  else
    local mirror rel meta
    mirror="https://distfiles.gentoo.org"
    _info "Auto-detecting latest desktop-openrc stage3 (amd64)"
    meta="$(wget -qO- --tries=3 "$mirror/releases/amd64/autobuilds/latest-stage3-amd64-desktop-openrc.txt" \
        || _die "Could not fetch stage3 metadata (offline?). Use --stage3 <url>.")"
    rel="$(printf '%s\n' "$meta" | awk '/\.tar\.(xz|zst)([[:space:]]|$)/{print $1; exit}')"
    [ -n "$rel" ] || _die "No stage3 filename in metadata"
    url="$mirror/releases/amd64/autobuilds/$rel"
  fi

  _info "Downloading stage3: $url"
  _run wget --continue --tries=3 --timeout=30 -O "$out" "$url"
  [ -s "$out" ] || _die "stage3 download failed"
  _ok "stage3 ready: $out"
}

# --------------------------------------------------------------------------
# 4. catalyst config
# --------------------------------------------------------------------------
_write_catalyst_conf(){
  _info "Writing catalyst config $CATALYST_CONF"
  # Just copy the host's catalyst.conf verbatim - no rewriting of values, no
  # injecting "snapshot_*"/"portdir" etc. (those are not valid conf keys and
  # cause "invalid value"). The host conf already parses on this machine.
  local sysconf="/etc/catalyst/catalyst.conf"
  if [ -f "$sysconf" ]; then
    _run cp -f "$sysconf" "$CATALYST_CONF"
    _ok "catalyst.conf copied from $sysconf"
  else
    _warn "No $sysconf found on this host; writing empty one."
    : > "$CATALYST_CONF"
  fi
}

# catalyst needs the source stage3 in its builds dir: <storedir>/builds/<rel_type>/...
_ensure_stage3_builds(){
  local storedir dest src
  storedir="$(awk -F'[ =:]+' '/^storedir/{print $2; exit}' "$CATALYST_CONF")"
  [ -n "$storedir" ] || storedir="/var/tmp/catalyst"
  dest="$storedir/builds/$STAGE3_RELDIR"
  src="$WORKDIR/distfiles/$STAGE3_RELDIR"
  if [ -s "$dest" ]; then
    _ok "stage3 already in catalyst builds dir: $dest"
    return
  fi
  [ -s "$src" ] || _die "No stage3 tarball at $src - run _ensure_stage3 first"
  mkdir -p "$(dirname "$dest")"
  _info "Placing stage3 in catalyst builds dir: $dest"
  if [ "$DRY" -eq 1 ]; then _info "[dry-run] link $src -> $dest"; return; fi
  # hardlink when possible (fast, no extra space); fall back to a copy
  if ! ln "$src" "$dest" 2>/dev/null; then
    cp -f "$src" "$dest"
  fi
  [ -s "$dest" ] || _die "Failed to place stage3 into catalyst builds dir"
  _ok "stage3 ready for catalyst: $dest"
}

# --------------------------------------------------------------------------
# 5. host prerequisites
# --------------------------------------------------------------------------
# When running on a Gentoo (live) GUI ISO, default tmpfs is only ~50% of RAM
# and can fill up fast during a build. Remount the key tmpfs mounts unlimited.
# Detect any live session: official Gentoo live uses /etc/init.d/livecd;
# Gentoo-based derivatives (CalamaroOS etc.) boot a live root on
# overlay/squashfs. Either signals a tmpfs-backed live GUI session.
_live_session(){
  [ -e /etc/init.d/livecd ] && return 0
  grep -Eq ' (overlay|squashfs|livecd)' /proc/mounts && return 0
  return 1
}
_max_tmpfs(){
  if [ "$DRY" -eq 1 ]; then _info "[dry-run] enlarge tmpfs to unlimited (size=0)"; return; fi
  _live_session || { _info "no live session detected; leaving tmpfs as-is"; return; }
  _info "Live session detected: enlarging tmpfs to unlimited (size=0)"
  mount -o remount,size=0 /tmp      2>/dev/null && _ok "enlarged /tmp"   || _warn "could not remount /tmp"
  mount -o remount,size=0 /var/tmp  2>/dev/null && _ok "enlarged /var/tmp" || _warn "could not remount /var/tmp"
  mount -o remount,size=0 /run      2>/dev/null && _ok "enlarged /run"   || _warn "could not remount /run"
}

_install_prereqs(){
  if _have catalyst && [ -f /etc/catalyst/catalyst.conf ]; then
    _ok "catalyst already installed"
    return
  fi
  _info "Installing catalyst + build host packages (first run takes a while)"
  _run emerge --ask=n --quiet-build=y --jobs="$JOBS" \
      "sys-devel/catalyst" \
      "app-arch/squashfs-tools" \
      "app-arch/pixz" \
      "sys-block/gptfdisk" \
      "sys-boot/grub" \
      "app-cdr/cdrtools" \
      "dev-vcs/git" \
      "app-arch/tar" \
        "net-misc/wget"
  _ok "catalyst and dependencies installed"
}

# --------------------------------------------------------------------------
# 6. run the build
# --------------------------------------------------------------------------
_run_stage1(){
  _info "== building portage snapshot (git treeish ${SNAP_REF:-HEAD}) =="
  mkdir -p "$WORKDIR/snapshot"
  _run catalyst -c "$CATALYST_CONF" -s "${SNAP_REF:-HEAD}" ${CATALYST_OPTS:-}
  _info "== livecd-stage1 =="
  _run catalyst -c "$CATALYST_CONF" -f "$CONF_STAGE1" ${CATALYST_OPTS:-}
}

_run_stage2(){
  _info "== livecd-stage2 =="
  _run catalyst -c "$CATALYST_CONF" -f "$CONF_STAGE2" ${CATALYST_OPTS:-}
}

_report(){
  local iso="$WORKDIR/StormG_xfce_08-06-2026.iso"
  # iso name comes from livecd/iso in stage2 spec; keep in sync
  iso="$(awk -F' *: *' '/^livecd\/iso:/{print $2}' "$CONF_STAGE2" 2>/dev/null || echo "$iso")"
  echo
  _ok "Build finished."
  printf '\033[36m  ISO: %s\033[0m\n' "$WORKDIR/$iso"
  _info "Verify (on the live ISO):  isoinfo -l -i $WORKDIR/$iso"
  _info "If calamares hangs on 'loading modules', see README: clear the target disk's filesystem (JFS etc.) first."
}

# --------------------------------------------------------------------------
# main
# --------------------------------------------------------------------------
main(){
  _info "StormG autocatalyst"
  _info "REPO_DIR=$REPO_DIR"
  _info "WORKDIR=$WORKDIR"
  _info "ONLY=$ONLY JOBS=$JOBS DRY=$DRY"
  trap _cleanup EXIT
  _max_tmpfs

  if [ "$ONLY" != stage2 ]; then
    _install_prereqs
    _fresh_sync
  fi
  _write_specs

  if [ "$ONLY" != stage2 ]; then
    _ensure_stage3
    _write_catalyst_conf
    _ensure_stage3_builds
    _run_stage1
  fi

  if [ "$ONLY" != stage1 ]; then
    [ -n "${KEEP:-}" ] || _write_catalyst_conf
    _run_stage2
  fi

  _report
}
main "$@"
