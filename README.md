# catalyst_stormg
Gentoo spec files for making stormg XFCE

## Calamares troubleshooting

(This repo's configs target **calamares 3.4.2** - pinned in the portage configs, see
`config/stages/package.mask/stage4`; the schemas are identical in 3.3.x.)

### Symptom: stuck on "loading modules (1 module …)" after launching calamares on the live ISO

This is a **disk probe hang**, not a `partition.conf` syntax problem. During startup the
`partition` module scans every storage device via KPMCore, then blocks until the scan finishes
(`PartitionViewStep::checkRequirements` -> `m_future->waitForFinished()`, verified in calamares
3.4.2 and unchanged from 3.3.x). If a device/filesystem stalls the probe, calamares never reaches
the welcome page.

Known trigger (calamares/calamares#2271): a JFS filesystem on the target disk. Other common
triggers: a flaky USB stick, a failing disk, stale LVM metadata, or a device with many partitions.

### First thing to try: `calamares-debug`

The live ISO ships a diagnostic wrapper (menu: *Calamares Diagnostics*, or run `sudo
calamares-debug` in a terminal). Instead of the wall of Qt noise that `calamares -d` produces
(and which looks identical whether it is working or hung), it:

1. **Probes every disk with a 5s timeout** and names the exact device that stalls the scan
   (Calamares itself just waits forever, with no error at all);
2. runs `calamares -d -D8` with output captured to `/root/calamares-debug-*.log` and kills it
   after 180s if hung;
3. cross-checks the calamares build for the Gentoo livecd modules and `settings.conf` against
   the module configs, so a missing config file is caught before calamares fails cryptically;
4. prints the last log lines plus a plain-English explanation of the common failure modes
   (including the gentoo `downloadstage3` / `gentoopkg` / `dracut_gentoo` / `stagechoose`
   tracebacks).

```sh
sudo calamares-debug             # full run: probe, run calamares, explain
sudo calamares-debug --probe     # just the disk probe (fast, no GUI)
sudo calamares-debug --log FILE  # explain an existing log instead of running
```

Workarounds for the probe hang:
- Clear/unmount the offending filesystem first (e.g. with GParted: `mkfs` or delete the partition),
  then re-run calamares.
- Try a different USB port / different drive; remove the live USB from the probe by booting it
  from a drive that is also the target, or disconnect non-essential disks.
- `defaultPartitionTableType` is now set to `gpt` in `partition.conf` (silences the
  "Partition-module setting *defaultPartitionTableType* is unset" warning in session.log).

### Portage: calamares pinned to 3.4.2 + the Gentoo livecd modules

`app-admin/calamares` is pinned to **3.4.2** so the schemas the configs above target cannot
silently drift:

- `config/stages/package.accept_keywords/stage4` and `.../calamares`: `=app-admin/calamares-3.4.2*`
  (only 3.4.2 revisions are keyword-accepted).
- `config/stages/package.mask/stage4`: `=app-admin/calamares-3.3.14-r1` (old config target) and
  `>=app-admin/calamares-3.4.3` (blocks newer bumps; drop that line to upgrade on purpose).
- `config/stages/package.use/calamares`: `app-admin/calamares livecd` - this applies the Gentoo
  livecd patch (TableFlipper9/gentoo-patches-3.4.2b), adding the gentoo installer modules
  `downloadstage3`, `gentoopkg`, `dracut_gentoo`, `stagechoose` plus the `calamares-pkexec`
  launcher, and pulls in `app-portage/gemato` for stage3 PGP verification. The default
  `settings.conf` does *not* use those modules (this build installs from the bundled squashfs via
  `unpackfs`), but they are available, and `calamares-debug` understands them.

### Config notes (already applied here)

- `root_overlay/etc/calamares/settings.conf` now defines the `instances:` entry for
  `shellprocess@locale` so `locale-gen` actually runs during install.
- `root_overlay/etc/calamares/modules/services-openrc.conf` had a YAML error
  (`mandatory" false` instead of `mandatory: false`) which made the `services-openrc` module fail
  to load; fixed so the listed OpenRC services get enabled on the installed system.
- `root_overlay/etc/calamares/modules/finished.conf` now uses `reboot` instead of
  `systemctl -i reboot` (this build is OpenRC, not systemd).
- `root_overlay/etc/calamares/modules/displaymanager.conf` defaults the desktop environment to XFCE.
- `root_overlay/etc/calamares/modules/partition.conf` now uses the `efi:` block (the top-level
  `efiSystemPartition:` alias is deprecated and only printed warnings), sets `luksGeneration`,
  and adds `essentialMounts: ["live-*", "control", "ventoy"]` so the partition step never tries
  to unmount the live system's own squashfs/USB mounts mid-install.
- `root_overlay/etc/calamares/modules/grubcfg.conf` was written for the old C++ grubcfg; on
  calamares 3.4.x/3.3.x (Python grubcfg) the null `defaults:` crashed the module with a cryptic
  traceback during install. Rewritten with the keys 3.4.x actually reads.
- `root_overlay/etc/calamares/modules/keyboard.conf` was a literal `[FILE_DOES_NOT_EXIST]`
  placeholder (invalid YAML -> confusing "failed to parse" warnings); replaced with a real
  config. `hwclock.conf` was the same placeholder; it is replaced by a minimal empty config
  (the module takes no keys, but a missing file makes calamares print "No config file for
  hwclock").
- `root_overlay/etc/calamares/modules/removeuser.conf` started with a leading space
  (` username: gentoo`), which is invalid YAML; fixed.
- `root_overlay/etc/calamares/modules/locale.conf` had `geoipUrl`/`geoipStyle` keys that the
  3.4.x locale module ignores; replaced with the proper `geoip:` documentation (GeoIP stays
  disabled).
- Removed dead Arch/systemd leftovers (`before.conf`, `shellprocess-first.conf`, `initcpio.conf`,
  `initcpiocfg.conf`, `modules/settings.conf`, `packages.bak.conf`, `unpackfs1.conf`,
  `unpackfs2.conf`, `postcfg.conf`, `ucode.conf`, `software.yaml.save*`, `drivers.yaml`,
  `net_drivers.conf`, `net_software.conf`, `software.yaml`, `luks.conf`,
  `windowexpander.conf`) and the corrupted `etc/calamares/launch.sh` (it was a saved GitHub HTML
  page, and nothing referenced it). `packages.conf`, `license.conf` and `shellprocess-base.conf`
  are also unreferenced by `settings.conf` but were kept (they reference existing files/values).
- New `calamares-debug` diagnostic tool ships in `root_overlay/usr/local/bin/` (plus a
  "Calamares Diagnostics" desktop entry) - see the troubleshooting section above.

### Building the ISO (anywhere): `autocatalyst.sh`

The two `*.spec` files bake in a build-host path (`/home/bennji/Desktop/catalyst_stormg/…`).
`autocatalyst.sh` de-hardcodes that: it copies the specs into `./build/`, swaps the baked-in
prefix for the real repo location, **fresh-syncs a current gentoo git tree** (plus `guru` and
`steam-overlay`) — so it does *not* depend on the stale bundled snapshot — then installs
`catalyst` + host packages, fetches a stage3, builds the snapshot, and runs livecd-stage1 then
livecd-stage2.

```sh
chmod +x autocatalyst.sh
sudo ./autocatalyst.sh                 # stage1 + stage2, all defaults
sudo ./autocatalyst.sh --only stage2   # resume from an existing stage1
sudo ./autocatalyst.sh --dry-run       # print the exact commands without running them
sudo ./autocatalyst.sh --stage3 URL    # pin a specific stage3; else latest desktop-openrc is auto-detected
./autocatalyst.sh                      # re-runs: reuses an already-downloaded stage3 tarball
```

Options / env overrides:
- `--stage3 <url>` / `STAGE3_URL` — pin the stage3 tarball (auto-detects latest otherwise).
- `--snapshot <ref>` — pin the gentoo treeish for the snapshot (default: fresh `HEAD` after sync).
- `BUILD_DATE=MM-DD-YYYY` — pin the date stamped into `version_stamp`, the stage1
  `source_subpath`, `livecd/iso` and `livecd/volid`. Default: today's date, autodetected.
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
`build/StormG_xfce_<MM-DD-YYYY>.iso` - the date is autodetected at build time (name comes from
`livecd/iso` in `livegui-stage2.spec`, which `autocatalyst.sh` stamps with the current date).

### Known remaining work
- Repo ships a *snapshot* gentoo tree in `overlay/var/db/repos/gentoo` (not a git clone), so the
  `snapshot_treeish` in the `*.spec` files is autodetected: the committed specs say `HEAD`, and
  `autocatalyst.sh` rewrites the line to the fresh-synced gentoo tree HEAD (or `--snapshot
  <ref>`) before building. Note: `profile: default/linux/amd64/23.0/desktop` must still exist in
  that fresh tree (23.0 profiles are still shipped, but this is the thing to re-check on a future
  sync).
- The `grub-theme-gentoo` cdtar referenced by `livegui-stage2.spec` comes from an installed Gentoo
  system; ensure `sys-boot/grub-themes-gentoo` (or the build host cdtar) is present on the build host.
- Pre-existing modified `overlay/var/db/repos/gentoo/dev-python/*/Manifest` files are from the stale
  bundled snapshot — not our edits; leave them alone.
- The committed `*.spec` still contain the hardcoded `/home/bennji/...` prefix by design; the
  build-time fix lives in `autocatalyst.sh`.
