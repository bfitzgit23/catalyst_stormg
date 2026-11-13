#!/usr/bin/env bash
# xfce-minimize.sh — strip Xfce down to the substrate Squall still needs.
#
# Squall already replaces: panel, taskbar/dock, desktop, launcher/app finder,
# file manager, settings hub, tray applets, power-menu UI. This masks the Xfce
# components that would otherwise start or draw, and leaves the four pieces we
# cannot replace yet: xfwm4, xfsettingsd, xfconf, xfce4-notifyd.
#
# Usage:
#   xfce-minimize.sh            # apply masks
#   xfce-minimize.sh --restore  # remove masks (stock Xfce behaviour back)
#   xfce-minimize.sh --dry-run  # show what would happen
set -euo pipefail

MODE="apply"
DRY=0
for arg in "$@"; do
    case "$arg" in
        --restore) MODE="restore" ;;
        --apply)   MODE="apply" ;;
        --dry-run) DRY=1 ;;
        -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
        *) echo "unknown option: $arg" >&2; exit 1 ;;
    esac
done

AUTOSTART="$HOME/.config/autostart"
STATE_DIR="$HOME/.config/squall"
STATE="$STATE_DIR/xfce-masked.txt"
PATTERNS='xfce4-panel|xfdesktop|xfce4-power-manager|xfce4-clipman|blueman|nm-applet|xfce4-appfinder'

say() { echo "  $*"; }

apply() {
    mkdir -p "$AUTOSTART" "$STATE_DIR"
    : > "$STATE"
    shopt -s nullglob
    for f in /etc/xdg/autostart/*.desktop; do
        base=$(basename "$f")
        [[ "$base" =~ $PATTERNS ]] || continue
        echo "$base" >> "$STATE"
        if [ "$DRY" = 1 ]; then
            say "[dry-run] mask $base"
        else
            printf '[Desktop Entry]\nType=Application\nName=%s\nHidden=true\nX-Squall-Masked=true\n' \
                "$base" > "$AUTOSTART/$base"
            say "masked $base"
        fi
    done

    # xfwm4 stays, but Squall draws the decoration/theme it should match
    if command -v xfconf-query >/dev/null 2>&1; then
        for kv in \
            "xfwm4 /general/use_compositing bool true" \
            "xfwm4 /general/vblank_mode string glx" \
            "xfce4-desktop /desktop-icons/style int 0" \
            "xfce4-desktop /desktop-menu/show bool false"
        do
            set -- $kv
            if [ "$DRY" = 1 ]; then
                say "[dry-run] xfconf $1 $2 = $4"
            else
                xfconf-query -c "$1" -p "$2" -t "$3" -s "$4" --create 2>/dev/null || true
            fi
        done
    fi

    say "kept: xfwm4 (WM/compositor), xfsettingsd (XSETTINGS), xfconf, xfce4-notifyd"
    say "masked components are listed in $STATE"
    say "log out and back in — or start the Squall session instead"
}

restore() {
    [ -f "$STATE" ] || { say "nothing to restore"; return 0; }
    while read -r base; do
        [ -n "$base" ] || continue
        if [ "$DRY" = 1 ]; then
            say "[dry-run] unmask $base"
        else
            rm -f "$AUTOSTART/$base"
            say "unmasked $base"
        fi
    done < "$STATE"
    [ "$DRY" = 1 ] || rm -f "$STATE"
    say "stock Xfce autostart restored"
}

echo "StormG — minimising Xfce ($MODE)"
case "$MODE" in
    apply)   apply ;;
    restore) restore ;;
esac
