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
#   DATA_DIR       bulk build data: portage trees + git objects, catalyst
#                  storedir, distfiles, glibc bump chroot
#                  (default: $WORKDIR, or /var/tmp/stormg-data in a container)
#   STAGE3_URL     stage3 tarball URL (else auto-detect latest)
#   --snapshot REF uses a specific gentoo treeish (default: fresh HEAD)
#   CATALYST_JOBS  make jobs (default: nproc)
#   CATALYST_OPTS  extra args passed to catalyst
#   GLIBC_MIN      minimum glibc the pre-stage1 bump targets (default 2.43-r2)
#   BUILD_DATE     build date used in version_stamp/iso/volid (default: today,
#                  format MM-DD-YYYY - same shape as the hardcoded 08-06-2026)
set -Eeuo pipefail

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
SCRATCH_MNT=""
ISO_FILE=""
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

# git wrapper for trees copied/extracted by another uid (containers, live ISOs),
# which would otherwise trip git's "dubious ownership" check.
_git(){ git -c safe.directory='*' "$@"; }

# True inside docker/podman/containerd (GitHub Actions runners included).
_in_container(){
  if [ -f /.dockerenv ] || [ -f /run/.containerenv ]; then return 0; fi
  if grep -qaE '(docker|containerd|kubepods|podman|libpod)' /proc/1/cgroup 2>/dev/null; then return 0; fi
  return 1
}

# Where the bulk, ephemeral build data lives: the imported portage tree plus
# its git objects, catalyst's storedir, the distfiles cache and the glibc bump
# chroot. In a container the workspace is normally bind-mounted from another
# OS, and Docker Desktop's filesystem bridge manages only a few hundred small
# files per minute (measured ~570); importing the 134k-file / ~720 MB portage
# tree into it takes ~4 hours and looks exactly like a hang. Keep it on the
# container's own disk and copy only the finished ISO back into the workspace.
if [ -n "${DATA_DIR:-}" ]; then
  DATA_DIR_FROM_ENV=1
elif _in_container; then
  DATA_DIR=/var/tmp/stormg-data
else
  DATA_DIR="$WORKDIR"
fi
REPOS_DIR="$DATA_DIR/repos"
DISTFILES_DIR="$DATA_DIR/distfiles"
SCRATCH_BASE="${SCRATCH_BASE:-$DATA_DIR/scratch}"

# Report the exact command and line that aborted the build. Without this a CI
# log ends in a bare "Process completed with exit code 1".
_on_err(){
  local rc=$? line="${BASH_LINENO[0]:-?}" src="${BASH_SOURCE[1]:-autocatalyst.sh}"
  trap - ERR
  printf '\n\033[31m[!] FAILED\033[0m exit %s: `%s`\n' "$rc" "${BASH_COMMAND:-?}" >&2
  printf '\033[31m[!]\033[0m %s line %s | WORKDIR=%s DATA_DIR=%s\n' \
    "${src##*/}" "$line" "${WORKDIR:-?}" "${DATA_DIR:-?}" >&2
  df -h "${DATA_DIR:-/}" "${WORKDIR:-/}" 2>/dev/null | sed 's/^/[!] /' >&2 || true
  if [ -n "${DATA_DIR_FROM_ENV:-}" ] || [ "${DATA_DIR:-}" = "${WORKDIR:-}" ]; then
    printf '\033[31m[!]\033[0m Re-run the same command to resume: %s keeps the synced tree, distfiles, bumped stage3 and catalyst chroots.\n' \
      "${DATA_DIR:-?}" >&2
  else
    printf '\033[31m[!]\033[0m To resume, keep %s across runs: docker run ... -v stormg-data:%s\n' \
      "${DATA_DIR:-?}" "${DATA_DIR:-?}" >&2
  fi
  exit "$rc"
}
trap '_on_err' ERR

# First value of `key = value` in a catalyst.conf/make.conf, quotes stripped.
_conf_val(){
  [ -f "$2" ] || return 1
  awk -v k="$1" 'index($0,k)==1 { sub("^" k "[ \t]*[=:][ \t]*",""); gsub(/"/,""); print; exit }' "$2" 2>/dev/null
}

# Accept the testing keyword for catalyst and enable the USE flags the build
# host needs. Idempotent on purpose: re-running the script must not duplicate
# lines in /etc/portage (the old inline patch did exactly that).
_portage_prep(){
  if [ "$DRY" -eq 1 ]; then _info "[dry-run] seed /etc/portage keywords + USE"; return 0; fi
  local arch kw use line
  case "$(uname -m)" in aarch64|arm64) arch=arm64 ;; *) arch=amd64 ;; esac
  kw=/etc/portage/package.accept_keywords/stormg-catalyst
  use=/etc/portage/package.use/stormg-catalyst
  if ! mkdir -p /etc/portage/package.accept_keywords /etc/portage/package.use 2>/dev/null; then
    _warn "cannot write /etc/portage; skipping keyword/USE setup"
    return 0
  fi
  printf 'dev-util/catalyst ~%s\n' "$arch" > "$kw"
  for line in 'sys-apps/util-linux python' 'sys-boot/grub grub_platforms_efi-32'; do
    grep -qxF "$line" "$use" 2>/dev/null || printf '%s\n' "$line" >> "$use"
  done
  _ok "catalyst keyword/USE flags configured ($arch)"
}

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
  # Unmount scratch BEFORE rm -rf: its backing dirs live under $WORKDIR.
  for m in $SCRATCH_MNT; do
    umount "$m" 2>/dev/null && _ok "unmounted scratch over $m" || true
  done
  if _in_container; then
    # docker / GitHub Actions: the bind-mounted workspace is the only place
    # that survives the container, so keep the ISO and build tree there.
    iso="$(find "$WORKDIR" -maxdepth 3 -name '*.iso' -print -quit 2>/dev/null)"
    if [ -n "$iso" ]; then _ok "ISO kept in workspace: $iso"; else _warn "No ISO built."; fi
    return "$rc"
  fi
  _copy_iso
  iso="$(find "$WORKDIR" -maxdepth 3 -name '*.iso' -print -quit 2>/dev/null)"
  if [ -n "${KEEP:-}" ] && [ -d "$WORKDIR" ]; then
    _warn "--keep set; build dir retained: $WORKDIR"
  elif [ -n "$iso" ] && [ "$COPY_OK" -eq 0 ] && [ "$DRY" -eq 0 ]; then
    _warn "ISO present but could not be copied to '$ISO_DIR'; keeping build dir."
  elif [ -d "$WORKDIR" ]; then
    _info "Removing build dir: $WORKDIR"
    rm -rf "$WORKDIR"
  fi
  return "$rc"
}

# --------------------------------------------------------------------------
# arg parsing
# --------------------------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --only=*)            ONLY="${1#*=}" ;;
    --only)              ONLY="$2"; shift ;;
    --stage3=*)          STAGE3_URL="${1#*=}" ;;
    --stage3)            STAGE3_URL="$2"; shift ;;
    --iso-dir=*)        ISO_DIR="${1#*=}" ;;
    --iso-dir)          ISO_DIR="$2"; shift ;;
    --snapshot=*)        SNAP_REF="${1#*=}"; SNAP_REF_EXPLICIT=1 ;;
    --snapshot)          SNAP_REF="$2"; SNAP_REF_EXPLICIT=1; shift ;;
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
# 0. keep the build stamp of an interrupted run
# --------------------------------------------------------------------------
# Catalyst identifies a build by version_stamp: the chroot and the autoresume
# markers live in <storedir>/tmp/livecd-stage[12]-amd64-stormg-<MM-DD-YYYY>.
# The specs are stamped with today's date, so re-running the day after a
# failure would create a NEW chroot and re-emerge all 600+ packages from
# scratch - the 11+ GB already merged thrown away. Unless BUILD_DATE is given
# explicitly, stay on the stamp of the newest unfinished stage (either a stage1
# without its tarball, or a stage1 tarball whose stage2 never finished).
_adopt_resume_date(){
  [ -z "${BUILD_DATE:-}" ] || return 0
  local storedir stamp
  storedir="$(_conf_val storedir /etc/catalyst/catalyst.conf 2>/dev/null || true)"
  [ -n "$storedir" ] || storedir=/var/tmp/catalyst
  if [ "$DRY" -eq 1 ]; then
    # _scratch_space skips its bind mount on a dry run; inspect the backing dir
    storedir="${SCRATCH_BASE:-$DATA_DIR/scratch}$(printf '%s' "$storedir" | tr '/' '_')"
  fi
  [ -d "$storedir/tmp" ] || return 0

  # Newest stamp first, ordered by the stamp itself (YYYYMMDD key) rather than
  # by directory mtime: every resume attempt touches the chroot, so mtime says
  # nothing about which build is actually the most recent one.
  local stamps
  stamps="$(
    { ls -1d "$storedir"/tmp/*/livecd-stage1-amd64-stormg-* 2>/dev/null
      ls -1d "$storedir"/tmp/*/livecd-stage2-amd64-stormg-* 2>/dev/null; } |
    sed 's#.*stormg-##' | sort -u |
    awk -F- 'NF==3 {print $3 $1 $2 " " $0}' | sort -r | cut -d' ' -f2)"

  _adopt_stamp(){
    if [ "$1" = "$DATE" ]; then
      _ok "resuming the unfinished $2 build $1"
    else
      _ok "resuming the unfinished $2 from $1 (today would be $DATE)"
      _info "catalyst keys its chroots by that stamp; BUILD_DATE=$DATE forces a fresh build (discards them)"
      DATE="$1"
    fi
  }

  while IFS= read -r stamp; do
    case "$stamp" in
      [0-9][0-9]-[0-9][0-9]-[0-9][0-9][0-9][0-9]) ;;
      *) continue ;;
    esac
    # no stage1 tarball yet: stage1 is what needs resuming
    if ! compgen -G "$storedir/builds/*/livecd-stage1-amd64-stormg-$stamp.tar.*" >/dev/null; then
      _adopt_stamp "$stamp" livecd-stage1
      return 0
    fi
    # stage1 done, but catalyst only removes a stage2 autoresume dir when the
    # stage2 build completes - so its presence means stage2 is unfinished and
    # source_subpath must keep naming this stamp's tarball.
    if compgen -G "$storedir/tmp/*/.autoresume-livecd-stage2-amd64-stormg-$stamp" >/dev/null; then
      _adopt_stamp "$stamp" livecd-stage2
      return 0
    fi
  done <<< "$stamps"
  return 0
}

# --------------------------------------------------------------------------
# 1. de-hardcode the specs into $WORKDIR
# --------------------------------------------------------------------------
_write_specs(){
  _info "Rewriting hardcoded '$OLD_PREFIX' -> '$REPO_DIR' in spec copies"
  mkdir -p "$WORKDIR"
  local esc escr escw
  esc="$(printf '%s' "$REPO_DIR"  | sed 's/[\\&]/\\&/g')"
  escr="$(printf '%s' "$REPOS_DIR" | sed 's/[\\&]/\\&/g')"
  escw="$(printf '%s' "$WORKDIR"    | sed 's/[\\&]/\\&/g')"
  # The committed specs carry a stale example date (stormg-08-06-2026 etc.);
  # stamp the real build date in, so version_stamp / source_subpath / iso /
  # volid all stay in sync and the output names reflect the day of the build.
  local dpat='[0-9][0-9]-[0-9][0-9]-[0-9][0-9][0-9][0-9]'
  for pair in "$SPEC_S1:$CONF_STAGE1" "$SPEC_S2:$CONF_STAGE2"; do
    local src="${pair%%:*}" dst="${pair#*:}"
    sed -e "s#${OLD_PREFIX}#${esc}#g" \
        -e "s#${esc}/overlay/var/db/repos/gentoo#${escr}/gentoo#g" \
        -e "s#${esc}/overlay/var/db/repos/guru#${escr}/guru#g" \
        -e "s#${esc}/overlay/var/db/repos/steam-overlay#${escr}/steam-overlay#g" \
        -e "s#stormg-${dpat}#stormg-${DATE}#g" \
        -e "s#livecd-stage1-amd64-stormg-${dpat}#livecd-stage1-amd64-stormg-${DATE}#g" \
        -e "s#StormG_xfce_${dpat}#StormG_xfce_${DATE}#g" \
        -e "s#StormG_LiveDVD_${dpat}#StormG_LiveDVD_${DATE}#g" \
        -e "s#^snapshot_treeish:.*#snapshot_treeish: ${SNAP_REF:-HEAD}#" \
        -e "s#^portage_confdir:.*#portage_confdir: ${escw}/portage-conf#" \
        "$src" > "$dst"
  done
  _ok "specs written (fresh git repos + treeish ${SNAP_REF:-HEAD}, date ${DATE})"
}

# --------------------------------------------------------------------------
# 2. snapshot - fresh sync (no reliance on the gitignored overlay/ tree)
# --------------------------------------------------------------------------
# The bundled overlay/var/db/repos/* tree is gitignored, so a clean checkout
# (docker image, GitHub Actions runner) has no portage tree at all. Sync one
# on the build host: emerge --sync first, emerge-webrsync if rsync is blocked
# or missing (the usual case in containers).
_ensure_host_tree(){
  local tree=/var/db/repos/gentoo
  if [ -d "$tree/profiles" ]; then
    _ok "host portage tree present: $tree"
    return 0
  fi
  _info "No portage tree at $tree (overlay/ is gitignored); running emerge --sync"
  if _run emerge --sync; then
    _ok "portage tree synced"
    return 0
  fi
  _warn "emerge --sync failed; falling back to emerge-webrsync"
  _run emerge-webrsync || _die "could not create a portage tree (emerge --sync and emerge-webrsync both failed)"
  _ok "portage tree synced via webrsync"
}

_fresh_sync(){
  _info "Fresh-syncing the gentoo tree + overlay repos"
  mkdir -p "$REPOS_DIR"

  if [ -d "$REPOS_DIR/gentoo/.git" ] && \
     _git -C "$REPOS_DIR/gentoo" remote get-url origin >/dev/null 2>&1; then
    _ok "gentoo clone present; pulling"
    _run _git -C "$REPOS_DIR/gentoo" pull --ff-only
  elif [ -d /var/db/repos/gentoo/profiles ]; then
    _info "Importing synced portage tree from /var/db/repos/gentoo"
    mkdir -p "$REPOS_DIR/gentoo"
    if [ -d "$REPOS_DIR/gentoo/.git" ]; then
      # Resume: refresh the working tree in place but KEEP the git history, so
      # an unchanged tree keeps the same treeish and catalyst autoresume still
      # finds its chroots instead of restarting from stage1.
      if [ "$DRY" -eq 0 ]; then
        if ! { _have rsync && rsync -a --delete --exclude=.git \
                 /var/db/repos/gentoo/ "$REPOS_DIR/gentoo/"; }; then
          _warn "rsync import failed; falling back to a full copy"
          ( cd "$REPOS_DIR/gentoo" && \
            find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} + )
          cp -a /var/db/repos/gentoo/. "$REPOS_DIR/gentoo/"
        fi
      else
        _info "[dry-run] rsync /var/db/repos/gentoo -> $REPOS_DIR/gentoo (keeping .git)"
      fi
    else
      _run rm -rf "$REPOS_DIR/gentoo"
      _run cp -a /var/db/repos/gentoo "$REPOS_DIR/gentoo"
    fi
    # An rsync/webrsync tree has no git history, but catalyst snapshots need a
    # treeish to archive. Commit the synced state (once, or when it changed).
    if [ "$DRY" -eq 0 ]; then
      if [ ! -d "$REPOS_DIR/gentoo/.git" ]; then
        _info "Creating local git history for the synced tree (catalyst snapshot_treeish)"
        _git -C "$REPOS_DIR/gentoo" init -q
      fi
      _git -C "$REPOS_DIR/gentoo" add -A -f 2>/dev/null || true
      if _git -C "$REPOS_DIR/gentoo" diff --cached --quiet 2>/dev/null; then
        _ok "synced tree unchanged since the last import; reusing its treeish"
      else
        _git -C "$REPOS_DIR/gentoo" -c user.name=catalyst -c user.email=catalyst@localhost \
            commit -qm "synced portage tree $(date +%Y-%m-%d)"
      fi
    fi
  else
    _info "cloning gentoo from $GENTOO_REPO ..."
    _run rm -rf "$REPOS_DIR/gentoo"
    _run git clone --depth=1 --quiet "$GENTOO_REPO" "$REPOS_DIR/gentoo"
  fi
  for pair in "guru:$GURU_REPO" "steam-overlay:$STEAM_REPO"; do
    local name="${pair%%:*}" url="${pair#*:}"
    if [ ! -d "$REPOS_DIR/$name/.git" ]; then
      _info "cloning $name ..."
      _run rm -rf "$REPOS_DIR/$name"
      _run git clone --depth=1 --quiet "$url" "$REPOS_DIR/$name"
    else
      _run _git -C "$REPOS_DIR/$name" pull --ff-only
    fi
  done

if [ "$SNAP_REF_EXPLICIT" -eq 0 ]; then
    SNAP_REF="$(_git -C "$REPOS_DIR/gentoo" rev-parse --short=12 HEAD 2>/dev/null || echo HEAD)"
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
  repodir="$(_conf_val repos_storedir "$hconf" || true)"
  if [ -z "$repodir" ]; then
    sd="$(_conf_val storedir "$hconf" || true)"
    repodir="${sd:-/var/tmp/catalyst}/repos"
  fi
  mkdir -p "$repodir"
  for name in gentoo guru steam-overlay; do
    src="$REPOS_DIR/$name"
    [ -d "$src/.git" ] || { _warn "no git checkout at $src to seed (rsync tree?); skipping"; continue; }
    dest="$repodir/$name.git"
    # Re-create it: a bare clone gets no fetch refspec, so a stale mirror
    # would not see the new treeish after a re-sync.
    if [ -d "$dest" ]; then
      _info "refreshing bare snapshot repo $dest"
      _run rm -rf "$dest"
    fi
    _info "seeding bare snapshot repo $dest"
    _run _git clone --bare --quiet "$src" "$dest"
  done
  _ok "snapshot repos ready under $repodir"
}

# --------------------------------------------------------------------------
# 3. stage3 tarball
# --------------------------------------------------------------------------
_ensure_stage3(){
  if [ "$DRY" -eq 1 ]; then _info "skipping stage3 fetch (dry-run)"; return; fi
  local dist="$DISTFILES_DIR"
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
  if [ "$DRY" -eq 1 ]; then _info "[dry-run] place stage3 in catalyst builds dir"; return; fi
  local storedir dest src
  storedir="$(_conf_val storedir "$CATALYST_CONF" || true)"
  [ -n "$storedir" ] || storedir="/var/tmp/catalyst"
  dest="$storedir/builds/$STAGE3_RELDIR"
  src="$DISTFILES_DIR/$STAGE3_RELDIR"
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
  local dir="$REPOS_DIR/gentoo/sys-libs/glibc" v
  [ -d "$dir" ] || return 1
  # Live ebuilds (9999, 2.44.9999) sort highest under sort -V, but emerging one
  # clones glibc from upstream git and rebuilds it from scratch - it is masked
  # for a reason and fails in a bare stage3 chroot. Only consider released PVs.
  v="$(ls "$dir"/glibc-*.ebuild 2>/dev/null \
        | sed -E 's#.*/glibc-(.*)\.ebuild#\1#' \
        | grep -vE '(^|\.)9999$' \
        | sort -V | tail -1)" || v=""
  [ -n "$v" ] || return 1
  printf '%s' "$v"
}

# True if the first dot-version is >= the second (via sort -V).
_ver_ge(){
  [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1)" = "$1" ]
}

# glibc PV actually INSIDE the (tarball) stage3 we're about to build from.
_stage3_glibc_installed(){
  local tar="$1" val pat
  [ -s "$tar" ] && [ -f "/usr/bin/tar" ] || return 1
  # gentoo stage3 tarballs store paths with a leading './', which a pattern
  # anchored at 'var/' never matches - try both so a bumped tarball is
  # recognised (that is what makes a re-run skip the bump instead of redoing it).
  #
  # PF is checked first: current portage no longer writes a PV file into the
  # vdb (the directory name is authoritative), and every failed pattern costs a
  # full decompression of the tarball.
  for pat in './var/db/pkg/sys-libs/glibc-*/PF' 'var/db/pkg/sys-libs/glibc-*/PF' \
             './var/db/pkg/sys-libs/glibc-*/PV' 'var/db/pkg/sys-libs/glibc-*/PV'; do
    # head -1 closes the pipe early (tar is killed with SIGPIPE), hence the
    # subshell: pipefail must not turn that into a failed assignment.
    val="$( ( tar -xJf "$tar" --wildcards --to-stdout "$pat" 2>/dev/null || true ) | head -1 )"
    val="${val#glibc-}"
    val="$(printf '%s' "$val" | tr -d '\r\n')"
    case "$val" in [0-9]*) printf '%s' "$val"; return 0 ;; esac
  done
  # Last resort: read it off the vdb directory name.
  val="$(tar -tJf "$tar" 2>/dev/null \
        | sed -nE 's#^\.?/?var/db/pkg/sys-libs/glibc-([^/]+)/$#\1#p' \
        | grep -vE '(^|\.)9999$' | sort -V | tail -1)" || val=""
  [ -n "$val" ] || return 1
  printf '%s' "$val"
}

# Next minor above a glibc PV: 2.44-r4 -> 2.45.
_glibc_mask_above(){
  local v="${1%%-*}" maj min
  maj="${v%%.*}"; min="${v#*.}"
  case "$v" in *.*) ;; *) return 1 ;; esac
  case "$min" in ''|*[!0-9]*) return 1 ;; esac
  printf '%s.%s' "$maj" "$((min+1))"
}

# The committed portage confdir masks >=sys-libs/glibc-2.43 ("new glibc tends
# to lead to trouble with sandbox"). Once a stage3 ships that glibc or newer,
# the mask makes portage fall back to the newest ALLOWED glibc - 2.42-r7 - and
# install it OVER the newer installed one, which the ebuild aborts with
# "Downgrading glibc is not supported and a sure way to destruction".
#
# Give catalyst a copy of the confdir whose glibc mask sits just above the
# glibc the seed stage3 actually carries: the candidate is then either that
# same version (nothing to do) or older than what is installed, which portage
# simply leaves alone. The original intent - hold back anything newer than the
# seed - is preserved.
_prepare_portage_confdir(){
  local src="$REPO_DIR/config/stages" dst="$WORKDIR/portage-conf"
  local tar="$DISTFILES_DIR/$STAGE3_RELDIR" pv thr f
  if [ "$DRY" -eq 1 ]; then
    _info "[dry-run] would copy $src to $dst and raise the glibc mask"
    return 0
  fi
  [ -d "$src" ] || { _warn "no portage confdir at $src; using catalyst defaults"; return 0; }
  rm -rf "$dst"
  cp -a "$src" "$dst" || _die "could not copy $src to $dst"
  pv="$(_stage3_glibc_installed "$tar")" || pv=""
  if [ -z "$pv" ]; then
    _warn "could not read the stage3's glibc PV; leaving the glibc mask as committed"
    return 0
  fi
  if ! thr="$(_glibc_mask_above "$pv")"; then
    _warn "unexpected glibc PV '$pv'; leaving the glibc mask as committed"
    return 0
  fi
  f="$dst/package.mask/releng/glibc"
  mkdir -p "$(dirname "$f")"
  cat > "$f" <<EOF
# Rewritten by autocatalyst.sh for this build: the seed stage3 carries
# sys-libs/glibc-$pv. Masking that version makes portage choose the newest
# ALLOWED glibc (an older one) and install it over the newer installed
# glibc, which aborts with "Downgrading glibc is not supported".
#
# The original intent is kept: hold back anything NEWER than the seed.
>=sys-libs/glibc-$thr
EOF
  # The newest glibc is usually still testing-keyworded, and catalyst's chroot
  # make.conf carries no ACCEPT_KEYWORDS of its own - without this, portage
  # falls back to the newest STABLE glibc, which is again older than the seed's.
  mkdir -p "$dst/package.accept_keywords"
  cat > "$dst/package.accept_keywords/glibc" <<EOF
# Added by autocatalyst.sh: the seed stage3 carries glibc $pv.
sys-libs/glibc ~$GLIBC_ACCEPT_ARCH
EOF
  _ok "portage confdir staged at $dst; glibc mask >=sys-libs/glibc-$thr, ~$GLIBC_ACCEPT_ARCH accepted (stage3 has $pv)"
}

# Unmount the live kernel filesystems we bind into the bump chroot. This MUST
# happen before the chroot is repacked: tarring a mounted sysfs/procfs fills the
# log with "File shrank by N bytes" / "Input/output error" / "Permission
# denied", exits 2, and writes a multi-GB archive of kernel state instead of a
# stage3.
_bump_unmount(){
  local root="$1" m
  for m in proc dev sys; do
    [ -d "$root/$m" ] || continue
    if _have mountpoint && ! mountpoint -q "$root/$m"; then continue; fi
    umount "$root/$m" 2>/dev/null || umount -l "$root/$m" 2>/dev/null || \
      _warn "could not unmount $root/$m; the repack excludes it"
  done
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
  tar="$DISTFILES_DIR/$STAGE3_RELDIR"
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
  # Never try to move glibc backwards: portage refuses it, and the failure is
  # only noise because the stage3 is already newer than the tree.
  if [ -n "$cur" ] && ! _ver_ge "$target" "$cur"; then
    _ok "stage3 glibc $cur is newer than the tree's $target; nothing to bump"
    return 0
  fi
  _info "Upgrading stage3 glibc to $target before catalyst stage1"
  local root="$DATA_DIR/bumproot" oldroot="$DISTFILES_DIR/stage3.bumped.tar.xz"
  rm -f "$oldroot" "$oldroot.part" 2>/dev/null || true
  # Resume: a previous attempt may already have emerged the target glibc and
  # then died while repacking. The emerge is the expensive part (tens of
  # minutes), so reuse the chroot instead of extracting + rebuilding it again.
  local need_emerge=1
  if [ -d "$root/var/db/pkg/sys-libs/glibc-$target" ]; then
    _ok "reusing bump chroot at $root (glibc $target already emerged)"
    need_emerge=0
  else
    rm -rf "$root"; mkdir -p "$root"
    _info "Extracting stage3 to $root"
    _run tar -xJf "$tar" -C "$root"
    # overlay the snapshot's portage tree so the chroot sees its glibc ebuild.
    # Skip .git: the copy is throwaway and the objects are ~700 MB.
    mkdir -p "$root/var/db/repos/gentoo"
    if [ "$DRY" -eq 0 ]; then
      tar -C "$REPOS_DIR/gentoo" --exclude=./.git -cf - . \
        | tar -C "$root/var/db/repos/gentoo" -xf - || _warn "could not overlay the portage tree into $root"
    fi
  fi
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
  cb="$(grep -Es '^(CHOST|CBUILD)=' /etc/portage/make.conf 2>/dev/null | head -1)" || cb=""
  case "$cb" in *aarch64*|*arm64*) arch="arm64" ;; *x86_64*|*amd64*) arch="amd64" ;; *) arch="amd64" ;; esac
  grep -q '^ACCEPT_KEYWORDS=' "$mkconf" 2>/dev/null || echo "ACCEPT_KEYWORDS=\"$arch ~$arch\"" >> "$mkconf"
  rootcmd="emerge -q --oneshot --nodeps \">=sys-libs/glibc-$GLIBC_MIN\" \">=sys-libs/glibc-$target\""
  rc=0
  if [ "$need_emerge" = 1 ]; then
    _info "Running the bump inside the chroot (this builds glibc; it takes a while)"
    chroot "$root" /bin/bash -lc "$rootcmd" || rc=$?
  else
    _ok "skipping the emerge; repacking the already-bumped chroot"
  fi
  # The chroot still has /proc, /dev and /sys bind-mounted from the emerge: a
  # tar of the root now would archive live kernel state (the endless "File
  # shrank by N bytes" / "Input/output error" noise) and fail. Unmount first.
  _bump_unmount "$root"
  local repacked=0
  if [ "$rc" -ne 0 ]; then
    # Never abort the whole build on a failed bump: the original stage3 may
    # still build fine, and catalyst's own error is far more informative than a
    # silent exit here.
    _warn "glibc bump to $target failed (rc=$rc); continuing with the original stage3"
    _warn "catalyst will build against whatever glibc the original stage3 carries"
    [ -n "${KEEP:-}" ] || rm -rf "$root"
  else
    # Build the new tarball beside the old one and only replace it once it is
    # complete and readable, so a failed repack (or a full disk) can never
    # destroy a working stage3.
    _info "Repacking bumped stage3"
    rm -f "$oldroot.part"
    if _run tar -cJf "$oldroot.part" -C "$root" --xattrs --acls \
         --exclude=./proc/* --exclude=./sys/* --exclude=./dev/* \
         --exclude=./var/tmp/portage/* --exclude=./var/cache/distfiles/* . \
       && [ -s "$oldroot.part" ] && tar -tJf "$oldroot.part" >/dev/null 2>&1; then
      _run mv -f "$oldroot.part" "$tar"
      repacked=1
      _ok "stage3 glibc bumped to $target"
    else
      rm -f "$oldroot.part"
      _warn "could not repack the bumped stage3; keeping the original tarball"
      _warn "the emerged chroot is kept at $root, so the next run skips the glibc rebuild"
    fi
  fi
  if [ "$repacked" -eq 1 ] && [ -z "${KEEP:-}" ]; then rm -rf "$root"; fi
  return 0
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
  if _in_container; then
    _info "Container detected: skipping live-session tmpfs remounts"
    return 0
  fi
  _live_session || { _info "no live session detected; leaving tmpfs as-is"; return; }
  _info "Live session detected: enlarging tmpfs to unlimited (size=0)"
  mount -o remount,size=0 /tmp      2>/dev/null && _ok "enlarged /tmp"     || _warn "could not remount /tmp"
  mount -o remount,size=0 /var/tmp  2>/dev/null && _ok "enlarged /var/tmp" || _warn "could not remount /var/tmp"
  mount -o remount,size=0 /run      2>/dev/null && _ok "enlarged /run"     || _warn "could not remount /run"
}

# Put the big consumer dirs (distfiles, catalyst's storedir) on the workspace
# volume so a container layer or live root cannot fill up mid-build.
_scratch_space(){
  if [ "$DRY" -eq 1 ]; then _info "[dry-run] create scratch bind mounts"; return; fi
  local hconf="/etc/catalyst/catalyst.conf" dist stored d backing
  local base="${SCRATCH_BASE:-$DATA_DIR/scratch}"
  mkdir -p "$base"
  dist="$(_conf_val distdir "$hconf" || true)";   [ -n "$dist" ]   || dist="/var/cache/distfiles"
  stored="$(_conf_val storedir "$hconf" || true)"; [ -n "$stored" ] || stored="/var/tmp/catalyst"
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
  _portage_prep
  _ensure_host_tree
  if _have catalyst && [ -f /etc/catalyst/catalyst.conf ] && _have git && _have wget; then
    _ok "catalyst already installed"
    return
  fi
  _info "Installing catalyst + build host packages (first run takes a while)"
  _run emerge --ask=n --quiet-build=y --jobs="$JOBS" \
      "dev-util/catalyst" \
      "sys-fs/squashfs-tools" \
      "app-arch/pixz" \
      "sys-apps/gptfdisk" \
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
# catalyst copies portage_confdir ONCE: setup_confdir returns immediately when
# its autoresume marker exists. A build resumed after the confdir changed would
# therefore keep the old (glibc-masking) copy in its chroot and fail again, so
# drop just that marker - catalyst re-rsyncs the confdir while unpack,
# chroot_setup and package progress stay untouched.
_force_confdir_refresh(){
  local storedir d n=0
  storedir="$(_conf_val storedir "$CATALYST_CONF" 2>/dev/null || true)"
  [ -n "$storedir" ] || storedir=/var/tmp/catalyst
  if [ "$DRY" -eq 1 ]; then
    _info "[dry-run] would clear catalyst setup_confdir resume markers under $storedir/tmp"
    return 0
  fi
  for d in "$storedir"/tmp/*/.autoresume-livecd-stage*/; do
    [ -d "$d" ] || continue
    [ -f "$d/setup_confdir" ] || continue
    rm -f "$d/setup_confdir" && n=$((n+1))
  done
  [ "$n" -eq 0 ] || _ok "cleared $n setup_confdir resume marker(s); the portage confdir will be re-copied"
  return 0
}

_run_stage1(){
  _accept_host_keywords
  _force_confdir_refresh
  _info "== building portage snapshot (git treeish ${SNAP_REF:-HEAD}) =="
  mkdir -p "$WORKDIR/snapshot"
  _run catalyst -c "$CATALYST_CONF" -s "${SNAP_REF:-HEAD}" ${CATALYST_OPTS:-}
  _info "== livecd-stage1 =="
  _run catalyst -c "$CATALYST_CONF" -f "$CONF_STAGE1" ${CATALYST_OPTS:-}
}

_run_stage2(){
  _force_confdir_refresh
  _info "== livecd-stage2 =="
  _run catalyst -c "$CATALYST_CONF" -f "$CONF_STAGE2" ${CATALYST_OPTS:-}
}

# catalyst writes the ISO under <storedir>/builds/livecd/, which is now on the
# container's own disk (or $WORKDIR/scratch on a host run). Copy it into the
# bind-mounted workspace so it survives the container and the GitHub Actions
# artifact upload really finds build/*.iso.
_collect_iso(){
  local stored src
  stored="$(_conf_val storedir "$CATALYST_CONF" || true)"
  [ -n "$stored" ] || stored=/var/tmp/catalyst
  if [ "$DRY" -eq 1 ]; then
    _info "[dry-run] copy ISO from $stored/builds/livecd into $WORKDIR"
    return 0
  fi
  if [ ! -d "$stored/builds" ]; then
    _warn "No catalyst builds dir at $stored/builds; no ISO to collect"
    return 0
  fi
  src="$(find "$stored/builds" -maxdepth 3 -name '*.iso' -print -quit 2>/dev/null || true)"
  if [ -z "$src" ]; then
    _warn "No ISO found under $stored/builds"
    return 0
  fi
  ISO_FILE="$WORKDIR/$(basename "$src")"
  if [ ! "$src" -ef "$ISO_FILE" ]; then
    _info "Copying ISO into the workspace: $ISO_FILE"
    cp -f "$src" "$ISO_FILE" || { _warn "could not copy ISO to $ISO_FILE"; return 0; }
  fi
  _ok "ISO ready: $ISO_FILE"
}

_report(){
  [ "$DRY" -eq 1 ] || [ -n "$ISO_FILE" ] || _collect_iso
  echo
  _ok "Build finished."
  if [ -n "$ISO_FILE" ] && [ -f "$ISO_FILE" ]; then
    printf '\033[36m  ISO: %s\033[0m\n' "$ISO_FILE"
    _info "Verify (on the live ISO):  isoinfo -l -i $ISO_FILE"
  fi
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

  # Not stage1-only: `--only stage2` in a fresh container still needs catalyst
  # installed and the storedir/distfiles bind-mounted from DATA_DIR, otherwise
  # catalyst sees an empty /var/tmp/catalyst and finds neither chroot nor
  # stage1 tarball (the "resume from an existing stage1" path in the README).
  _install_prereqs
  _scratch_space
  if [ "$ONLY" != stage2 ]; then
    _fresh_sync
    _seed_snapshot_repos
  fi
  _adopt_resume_date
  _write_specs

  if [ "$ONLY" != stage2 ]; then
    _ensure_stage3
    _write_catalyst_conf
    _bump_glibc
    _ensure_stage3_builds
    _prepare_portage_confdir
    _run_stage1
  fi

  if [ "$ONLY" != stage1 ]; then
    [ -n "${KEEP:-}" ] || _write_catalyst_conf
    # Re-stage the confdir on every run: it is generated (glibc mask, accept
    # keywords) and then copied into the chroot, so reusing a copy from an
    # earlier run would silently ignore edits to config/stages - which is how
    # a stale glibc mask and a stale package.use survive a resume.
    _prepare_portage_confdir
    _run_stage2
    _collect_iso
  fi

  _report
}
main "$@"
