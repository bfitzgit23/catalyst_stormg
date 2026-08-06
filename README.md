# catalyst_stormg
Gentoo spec files for making stormg XFCE

## Calamares troubleshooting

### Symptom: stuck on "loading modules (1 module …)" after launching calamares on the live ISO

This is a **disk probe hang**, not a `partition.conf` syntax problem. During startup the
`partition` module scans every storage device via KPMCore, then blocks until the scan finishes
(`PartitionViewStep::checkRequirements` -> `m_future->waitForFinished()` in calamares 3.3.14).
If a device/filesystem stalls the probe, calamares never reaches the welcome page.

Known trigger (calamares/calamares#2271): a JFS filesystem on the target disk. Other common
triggers: a flaky USB stick, a failing disk, stale LVM metadata, or a device with many partitions.

Diagnose on the live ISO:

```sh
tail -n 50 /root/.cache/calamares/session.log
# or launch in debug mode and watch:
calamares -d -D8
```

The last log lines before the hang show which device/scan stalled.

Workarounds:
- Clear/unmount the offending filesystem first (e.g. with GParted: `mkfs` or delete the partition),
  then re-run calamares.
- Try a different USB port / different drive; remove the live USB from the probe by booting it
  from a drive that is also the target, or disconnect non-essential disks.
- `defaultPartitionTableType` is now set to `gpt` in `partition.conf` (silences the
  "Partition-module setting *defaultPartitionTableType* is unset" warning in session.log).

### Config notes (already applied here)

- `root_overlay/etc/calamares/settings.conf` now defines the `instances:` entry for
  `shellprocess@locale` so `locale-gen` actually runs during install.
- `root_overlay/etc/calamares/modules/services-openrc.conf` had a YAML error
  (`mandatory" false` instead of `mandatory: false`) which made the `services-openrc` module fail
  to load; fixed so the listed OpenRC services get enabled on the installed system.
- `root_overlay/etc/calamares/modules/finished.conf` now uses `reboot` instead of
  `systemctl -i reboot` (this build is OpenRC, not systemd).
- `root_overlay/etc/calamares/modules/displaymanager.conf` defaults the desktop environment to XFCE.
- Removed dead Arch/systemd leftovers (`before.conf`, `shellprocess-first.conf`, `initcpio.conf`,
  `initcpiocfg.conf`, `modules/settings.conf`, `packages.bak.conf`) and the corrupted
  `etc/calamares/launch.sh` (it was a saved GitHub HTML page, and nothing referenced it).

### Building the ISO (anywhere): `autocatalyst.sh`

The two `*.spec` files bake in a build-host path (`/home/bennji/Desktop/catalyst_stormg/…`).
`autocatalyst.sh` de-hardcodes that: it copies the specs into `./build/`, swaps the baked-in
prefix for the real repo location, **fresh-syncs a current gentoo git tree** (plus `guru` and
`steam-overlay`) — so it does *not* depend on the stale bundled snapshot — then installs
`catalyst` + host packages, fetches a stage3, builds the snapshot, and runs livecd-stage1 then
livecd-stage2.

```sh
sudo ./autocatalyst.sh                 # stage1 + stage2, all defaults
sudo ./autocatalyst.sh --only stage2   # resume from an existing stage1
sudo ./autocatalyst.sh --dry-run       # print the exact commands without running them
```

Options / env overrides:
- `--stage3 <url>` / `STAGE3_URL` — pin the stage3 tarball (auto-detects latest otherwise).
- `--snapshot <ref>` — pin the gentoo treeish for the snapshot (default: fresh `HEAD` after sync).
- `-j <jobs>` / `CATALYST_JOBS` — make jobs (default `nproc`).
- `--keep` — don't regenerate `$WORKDIR/catalyst.conf` before stage2.
- `REPO_DIR`, `WORKDIR` — override where the repo and the build live.

**Why it works on a live GUI ISO:** catalyst is Gentoo-only (it drives `emerge` + a stage3
chroot), but a system booted from the live GUI ISO is already Gentoo, so this script runs
directly there — it just needs the repo checkout + internet to fetch the stage3 tarball.

**Building on other distros (Arch/Ubuntu/…):** a *native* catalyst build outside Gentoo is not
possible. The supported route is to run this script inside a Gentoo container — same tooling
Gentoo Release Engineering uses:

```sh
# Ubuntu/Debian/Arch/Fedora — any box with Docker (or Podman):
#  1. official stage3 image provides a Gentoo rootfs
#  2. bind-mount this repo inside it
docker run -it --privileged \
  -v "$PWD":/build-stormg \
  gentoo/stage3:amd64-openrc \
  bash -c "cd /build-stormg && REPO_DIR=/build-stormg ./autocatalyst.sh"
```

(For Podman: same command with `podman` and add `--userns=keep-id` / `--privileged` as needed;
running needs `--privileged` so catalyst can mount the stage3 chroot.) The ISO lands in
`build/StormG_xfce_08-06-2026.iso` (name comes from `livecd/iso` in `livegui-stage2.spec`).

### Known remaining work
- Repo ships a *snapshot* gentoo tree in `overlay/var/db/repos/gentoo` (not a git clone), so the
  pinned `snapshot_treeish` in `livegui-stage1.spec` is informational. `autocatalyst.sh` ignores
  it and fresh-syncs a current gentoo git tree instead, using HEAD (or `--snapshot <ref>`) as the
  treeish. Note: `profile: default/linux/amd64/23.0/desktop` must still exist in that fresh tree
  (23.0 profiles are still shipped, but this is the thing to re-check on a future sync).
- The `grub-theme-gentoo` cdtar referenced by `livegui-stage2.spec` comes from an installed Gentoo
  system; ensure `sys-boot/grub-themes-gentoo` (or the build host cdtar) is present on the build host.
- Pre-existing modified `overlay/var/db/repos/gentoo/dev-python/*/Manifest` files are from the stale
  bundled snapshot — not our edits; leave them alone.
- The committed `*.spec` still contain the hardcoded `/home/bennji/...` prefix by design; the
  build-time fix lives in `autocatalyst.sh`.
