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
#                          [--no-bump-glibc] [-j <jobs>] [--keep] [--dry-run]
#
#   Before catalyst stage1, the stage3's glibc is upgraded to the newest the
#   snapshot tree can install (>= GLIBC_MIN, default 2.43-r2) with testing
#   KEYWORDS accepted, so catalyst never aborts with "Downgrading glibc is not
#   supported". Disable with --no-bump-glibc.
#
# Env overrides:
#   REPO_DIR       repo root   (default: directory containing this script)
#   WORKDIR        build work  (default: $REPO_DIR/build)
#   STAGE3_URL     stage3 tarball URL (else auto-detect latest)
#   --snapshot REF uses a specific gentoo treeish (default: fresh HEAD)
#   CATALYST_JOBS  make jobs (default: nproc)
#   CATALYST_OPTS  extra args passed to catalyst
#   GLIBC_MIN      minimum glibc the pre-stage1 bump targets (default 2.43-r2)
#   BUILD_DATE     build date used in version_stamp/iso/volid (default: today,
#                  format MM-DD-YYYY - same shape as the hardcoded 08-06-2026)
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
# Where to save the finished ISO - the installed CalamaroOS SSD (user Desktop).
# Override with $ISO_DIR or --iso-dir.
ISO_DIR="${ISO_DIR:-$HOME/Desktop}"
SCRATCH_BASE=""
SCRATCH_MNT=""
BUMP_GLIBC="${BUMP_GLIBC:-1}"
GLIBC_MIN="${GLIBC_MIN:-2.43-r2}"
HOST_MAKE_CONF="${HOST_MAKE_CONF:-/etc/portage/make.conf}"
GLIBC_ACCEPT_ARCH="${GLIBC_ACCEPT_ARCH:-amd64}"
ONLY='all'
DRY=0
JOBS="${CATALYST_JOBS:-$(nproc)}"
SNAP_REF=""            # resolved below: SHA of the fresh gentoo tree (or --snapshot override)
SNAP_REF_EXPLICIT=0
# Build date - autodetected so the ISO/spec names carry the day you build.
# Override with BUILD_DATE=MM-DD-YYYY to pin a specific date.
DATE="${BUILD_DATE:-$(date +%m-%d-%Y)}"
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
  if [ "$DRY" -eq 1 ]; then _info "[dry-run] cp $found $ISO_DIR/"; return 0; fi
  if ! mkdir -p "$ISO_DIR" 2>/dev/null; then
    _warn "Cannot access ISO dir '$ISO_DIR' (does it exist?)."
    return 0
  fi
  if cp -f "$found" "$ISO_DIR/" 2>/dev/null; then
    _ok "ISO saved to $ISO_DIR/$(basename "$found")"
    COPY_OK=1
  else
    _warn "Failed to copy ISO to '$ISO_DIR'"
  fi
}
# On success OR failure: save the ISO to the Windows drive, then remove the
# build dir (unless --keep). Never delete a real ISO we couldn't save.
_cleanup(){
  local rc=$?
  local iso m
  _drop_host_keywords
  _copy_iso
  iso="$(find "$WORKDIR" -maxdepth 3 -name '*.iso' -print -quit 2>/dev/null)"
  if [ -n "${KEEP:-}" ] && [ -d "$WORKDIR" ]; then
    _warn "--keep set; build dir retained: $WORKDIR"
  elif [ -n "$iso" ] && [ "$COPY_OK" -eq 0 ] && [ "$DRY" -eq 0 ]; then
    _warn "ISO present but could not be copied to '$ISO_DIR'; keeping build dir."
  else
    [ -d "$WORKDIR" ] && { _info "Removing build dir: $WORKDIR"; rm -rf "$WORKDIR"; }
  fi
  for m in $SCRATCH_MNT; do
    umount "$m" 2>/dev/null && _ok "unmounted scratch over $m"
  done
  return "$rc"
}

# --------------------------------------------------------------------------
# arg parsing
# --------------------------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --only=*)            ONLY="${1#*=}" ;;
    --stage3=*)          STAGE3_URL="${1#*=}" ;;
    --iso-dir=*)        ISO_DIR="${1#*=}" ;;
    --snapshot=*)        SNAP_REF="${1#*=}"; SNAP_REF_EXPLICIT=1 ;;
    --bump-glibc)        BUMP_GLIBC=1 ;;
    --no-bump-glibc)     BUMP_GLIBC=0 ;;
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
  # The committed specs carry a stale example date (stormg-08-06-2026 etc.);
  # stamp the real build date in, so version_stamp / source_subpath / iso /
  # volid all stay in sync and the output names reflect the day of the build.
  local dpat='[0-9][0-9]-[0-9][0-9]-[0-9][0-9][0-9][0-9]'
  for pair in "$SPEC_S1:$CONF_STAGE1" "$SPEC_S2:$CONF_STAGE2"; do
    local src="${pair%%:*}" dst="${pair#*:}"
    sed -e "s#${OLD_PREFIX}#${esc}#g" \
        -e "s#${esc}/overlay/var/db/repos/gentoo#${escw}/repos/gentoo#g" \
        -e "s#${esc}/overlay/var/db/repos/guru#${escw}/repos/guru#g" \
        -e "s#${esc}/overlay/var/db/repos/steam-overlay#${escw}/repos/steam-overlay#g" \
        -e "s#stormg-${dpat}#stormg-${DATE}#g" \
        -e "s#livecd-stage1-amd64-stormg-${dpat}#livecd-stage1-amd64-stormg-${DATE}#g" \
        -e "s#StormG_xfce_${dpat}#StormG_xfce_${DATE}#g" \
        -e "s#StormG_LiveDVD_${dpat}#StormG_LiveDVD_${DATE}#g" \
        -e "s#^snapshot_treeish:.*#snapshot_treeish: ${SNAP_REF:-HEAD}#" \
        "$src" > "$dst"
  done
  _ok "specs written (fresh git repos + treeish ${SNAP_REF:-HEAD}, date ${DATE})"
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
# 2b. seed git snapshot repos into the host catalyst repos store
# --------------------------------------------------------------------------
_seed_snapshot_repos(){
  _info "Seeding catalyst git-snapshot repos (bare mirrors for the host)"
  local hconf="/etc/catalyst/catalyst.conf" repodir sd name src dest
  # catalyst snapshot reads bare repos from repos_storedir (default <storedir>/repos)
  repodir="$(awk -F'[ =:]+' '/^repos_storedir/{print $2; exit}' "$hconf" 2>/dev/null)"
  if [ -z "$repodir" ]; then
    sd="$(awk -F'[ =:]+' '/^storedir/{print $2; exit}' "$hconf" 2>/dev/null)"
    repodir="${sd:-/var/tmp/catalyst}/repos"
  fi
  mkdir -p "$repodir"
  for name in gentoo guru steam-overlay; do
    src="$WORKDIR/repos/$name"
    [ -d "$src/.git" ] || { _warn "no clone at $src to seed"; continue; }
    dest="$repodir/$name.git"
    if [ -d "$dest" ]; then
      _info "updating bare snapshot repo $dest"
      _run git -C "$dest" remote update --prune
    else
      _info "seeding bare snapshot repo $dest"
      _run git clone --bare --quiet "$src" "$dest"
    fi
  done
  _ok "snapshot repos ready under $repodir"
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
  # Pure host copy - generate nothing, rewrite nothing. The host's conf is
  # already valid for catalyst on this machine, so using it verbatim cannot
  # trip any "invalid value" parse error.
  _run cp -f "/etc/catalyst/catalyst.conf" "$CATALYST_CONF"
}

# catalyst needs the source stage3 in its builds dir: <storedir>/builds/<rel_type>/...
_ensure_stage3_builds(){
  local storedir dest src
  storedir="$(awk -F'[ =:]+' '/^storedir/{print $2; exit}' "$CATALYST_CONF")"
  [ -n "$storedir" ] || storedir="/var/tmp/catalyst"
  dest="$storedir/builds/$STAGE3_RELDIR"
  src="$WORKDIR/distfiles/$STAGE3_RELDIR"
  if [ -s "$dest" ] && [ "$dest" -nt "$src" ]; then
    _ok "stage3 already in catalyst builds dir: $dest"
    return
  fi
  [ -s "$src" ] || _die "No stage3 tarball at $src - run _ensure_stage3 first"
  mkdir -p "$(dirname "$dest")"
  # refresh a stale (e.g. glibc-bumped) copy before placing
  [ -e "$dest" ] && rm -f "$dest"
  _info "Placing stage3 in catalyst builds dir: $dest"
  if [ "$DRY" -eq 1 ]; then _info "[dry-run] link $src -> $dest"; return; fi
  # hardlink when possible (fast, no extra space); fall back to a copy
  if ! ln "$src" "$dest" 2>/dev/null; then
    cp -f "$src" "$dest"
  fi
  [ -s "$dest" ] || _die "Failed to place stage3 into catalyst builds dir"
  _ok "stage3 ready for catalyst: $dest"
}

# Newest glibc PV available in the freshly-synced snapshot gentoo tree.
_snapshot_glibc_newest(){
  local dir="$WORKDIR/repos/gentoo/sys-libs/glibc"
  [ -d "$dir" ] || return 1
  ls "$dir"/glibc-*.ebuild 2>/dev/null | sed -E 's#.*/glibc-(.*)\.ebuild#\1#' | sort -V | tail -1
}

# True if the first dot-version is >= the second (via sort -V).
_ver_ge(){
  [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1)" = "$1" ]
}

# glibc PV actually INSIDE the (tarball) stage3 we're about to build from.
_stage3_glibc_installed(){
  local tar="$1" pv
  [ -s "$tar" ] && [ -f "/usr/bin/tar" ] || return 1
  pv="$(tar -xJf "$tar" --wildcards --to-stdout 'var/db/pkg/sys-libs/glibc-*/PV' 2>/dev/null | head -1)"
  [ -n "$pv" ] || return 1
  printf '%s' "$pv"
}

# Catalyst dies ("Downgrading glibc is not supported") when the stage3's glibc
# is newer than what the snapshot profile wants to build. Prevent that by
# upgrading the stage3 chroot's glibc to the snapshot's newest FIRST, so the
# toolchain merge is at worst an upgrade. This replicates a mini stage1.
_bump_glibc(){
  if [ "${BUMP_GLIBC:-1}" != 1 ]; then
    _info "glibc bump disabled (BUMP_GLIBC=0 / --no-bump-glibc)"
    return 0
  fi
  if [ "$DRY" -eq 1 ]; then _info "[dry-run] skip glibc bump"; return 0; fi
  local tar newest cur target root rootcmd rc mkconf cb arch
  tar="$WORKDIR/distfiles/$STAGE3_RELDIR"
  [ -s "$tar" ] || { _warn "no source stage3 tarball; skipping glibc bump"; return 0; }
  newest="$(_snapshot_glibc_newest)" || { _warn "cannot resolve snapshot glibc; skipping bump"; return 0; }
  cur="$(_stage3_glibc_installed "$tar")" || cur=""
  target="$newest"
  if ! _ver_ge "$target" "$GLIBC_MIN"; then
    _warn "snapshot newest glibc ($target) below requested floor ($GLIBC_MIN); using $target"
  fi
  _info "glibc: inside-stage3=${cur:-?}  snapshot-newest=$newest  target=$target"
  if [ -n "$cur" ] && [ "$cur" = "$target" ]; then
    _ok "stage3 glibc already at target; nothing to bump"
    return 0
  fi
  _info "Upgrading stage3 glibc to $target before catalyst stage1"
  local root="$WORKDIR/bumproot"
  rm -rf "$root"; mkdir -p "$root"
  _run tar -xJf "$tar" -C "$root"
  # overlay the snapshot's portage tree so the chroot sees its glibc ebuild
  mkdir -p "$root/var/db/repos"
  rm -rf "$root/var/db/repos/gentoo"
  cp -a "$WORKDIR/repos/gentoo" "$root/var/db/repos/gentoo"
  if [ "${GENTOO_BIND:-1}" = 1 ]; then
    mount --bind /proc "$root/proc" 2>/dev/null || _warn "no /proc bind"
    mount --bind /dev "$root/dev"   2>/dev/null || _warn "no /dev bind"
    mount --bind /sys "$root/sys"   2>/dev/null || _warn "no /sys bind"
  fi
  [ -e "$root/etc/resolv.conf" ] || cp -f /etc/resolv.conf "$root/etc/resolv.conf" 2>/dev/null
  local mkconf="$root/etc/portage/make.conf"
  [ -f "$mkconf" ] || mkdir -p "$(dirname "$mkconf")"
  grep -Es '^ *(CHOST|CFLAGS|CPPFLAGS|LDFLAGS|MAKEOPTS|FEATURES)=' /etc/portage/make.conf 2>/dev/null >> "$mkconf" 2>/dev/null || :
  # accept the newest glibc (incl. testing) so catalyst's stable-only resolution
  # can never fall below the stage3's glibc.
  cb="$(grep -Es '^(CHOST|CBUILD)=' /etc/portage/make.conf 2>/dev/null | head -1)"
  case "$cb" in *aarch64*|*arm64*) arch="arm64" ;; *x86_64*|*amd64*) arch="amd64" ;; *) arch="amd64" ;; esac
  echo "ACCEPT_KEYWORDS=\"$arch ~$arch\"" >> "$mkconf"
  rootcmd="emerge -q --oneshot --nodeps \">=sys-libs/glibc-$GLIBC_MIN\" \">=sys-libs/glibc-$target\""
  chroot "$root" /bin/bash -lc "$rootcmd"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    _warn "glibc bump to $target failed; retrying with newest $newest"
    rootcmd="emerge -q --oneshot --nodeps \">=sys-libs/glibc-$newest\""
    chroot "$root" /bin/bash -lc "$rootcmd"
    rc=$?
  fi
  if [ "$rc" -ne 0 ]; then
    _warn "glibc bump failed (rc=$rc); continuing with original stage3"
  else
    _info "Repacking bumped stage3"
    _run tar -cJf "$WORKDIR/distfiles/stage3.bumped.tar.xz" -C "$root" --xattrs --acls .
    [ -s "$WORKDIR/distfiles/stage3.bumped.tar.xz" ] && _run mv -f "$WORKDIR/distfiles/stage3.bumped.tar.xz" "$tar"
    _ok "stage3 glibc bumped to $target"
  fi
  for m in proc dev sys; do umount "$root/$m" 2>/dev/null || true; done
  return "$rc"
}

# Catalyst builds each stage's chroot make.conf off the HOST's
# /etc/portage/make.conf. Without accepting testing KEYWORDS there, catalyst
# resolves the newest STABLE glibc and can still try a downgrade against a
# bumped stage3. Temporarily add an ACCEPT_KEYWORDS marker to the host conf,
# then roll it back in _cleanup() (also see _drop_host_keywords).
_accept_host_keywords(){
  [ "$DRY" -eq 1 ] && { _info "[dry-run] would accept testing glibc in host make.conf"; return 0; }
  local mk="$HOST_MAKE_CONF" arch="$GLIBC_ACCEPT_ARCH" offmatch
  [ -f "$mk" ] || return 0
  if grep -q '^#<stormg-bump-glibc>' "$mk"; then return 0; fi  # already injected
  printf '\n#<stormg-drop-glibc>\nACCEPT_KEYWORDS="%s ~%s"\n#</stormg-drop-glibc>\n' "$arch" "$arch" >> "$mk"
  _ok "accepted testing glibc in host make.conf ($arch ~$arch)"
}
_drop_host_keywords(){
  local mk="$HOST_MAKE_CONF"
  [ -f "$mk" ] && sed -i '/^#<stormg-drop-glibc>$/,/^#<\/stormg-drop-glibc>$/d' "$mk" 2>/dev/null || true
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

# The host catalyst distdir/storedir (e.g. /var/cache/distfiles) often sit on a
# small tmpfs on a live ISO. Without rewriting catalyst.conf we bind-mount big
# scratch storage over those dirs so downloads/builds don't run out of space.
_scratch_space(){
  if [ "$DRY" -eq 1 ]; then _info "[dry-run] create scratch bind mounts"; return; fi
  local hconf="/etc/catalyst/catalyst.conf" dist stored base d backing
  base="${SCRATCH_BASE:-}"
  if [ -z "$base" ]; then
    base="$WORKDIR/scratch"
  fi
  mkdir -p "$base"
  dist="$(awk -F'[ =:]+' '/^distdir/{print $2; exit}' "$hconf" 2>/dev/null)"; [ -n "$dist" ]  || dist="/var/cache/distfiles"
  stored="$(awk -F'[ =:]+' '/^storedir/{print $2; exit}' "$hconf" 2>/dev/null)"; [ -n "$stored" ] || stored="/var/tmp/catalyst"
  for d in "$dist" "$stored"; do
    case "$d" in /*) ;; *) continue ;; esac
    mkdir -p "$d"
    backing="$base$(printf '%s' "$d" | tr '/' '_')"
    mkdir -p "$backing"
    if mount --bind "$backing" "$d" 2>/dev/null; then
      _ok "big scratch bind-mounted over $d"
      SCRATCH_MNT="${SCRATCH_MNT} $d"
    else
      _warn "could not bind-mount scratch over $d"
    fi
  done
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
  _accept_host_keywords
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
  local iso="$WORKDIR/StormG_xfce_${DATE}.iso"
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
  _info "ONLY=$ONLY JOBS=$JOBS DRY=$DRY DATE=$DATE"
  trap _cleanup EXIT
  _max_tmpfs
  _scratch_space

  if [ "$ONLY" != stage2 ]; then
    _install_prereqs
    _fresh_sync
    _seed_snapshot_repos
  fi
  _write_specs

  if [ "$ONLY" != stage2 ]; then
    _ensure_stage3
    _write_catalyst_conf
    _bump_glibc
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
