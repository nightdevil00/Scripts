#!/usr/bin/env bash
# Fix Aequalyn/Limine 12 boot entries:
#  - create /etc/kernel/cmdline (limine-entry-tool needs it)
#  - drop the shadow configs in EFI/limine and EFI/BOOT
#  - regenerate the managed /boot/limine.conf (OS + //kernel + snapshots)
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo $0" >&2; exit 1; }

ESP=/boot
CONF=$ESP/limine.conf
STAMP=$(date +%Y%m%d-%H%M%S)
BK=/root/limine-backup-$STAMP

echo "[1/5] backing up current configs to $BK"
mkdir -p "$BK"
for f in "$CONF" "$CONF.old" "$ESP/EFI/limine/limine.conf" "$ESP/EFI/BOOT/limine.conf"; do
    if [ -f "$f" ]; then
        # Keep the original directory layout: several of these are named
        # limine.conf and used to overwrite each other in a flat backup dir.
        dest="$BK/${f#/}"
        mkdir -p "$(dirname "$dest")"
        cp -a "$f" "$dest"
    fi
done
find "$BK" -type f -printf '%p\n'

echo "[2/5] writing /etc/kernel/cmdline from the running kernel"
install -d -m 755 /etc/kernel
tr -d '\n' < /proc/cmdline > /etc/kernel/cmdline
printf '\n' >> /etc/kernel/cmdline
chmod 644 /etc/kernel/cmdline
cat /etc/kernel/cmdline

echo "[3/5] removing shadow and stale configs"
rm -f "$ESP/EFI/limine/limine.conf" "$ESP/EFI/BOOT/limine.conf" "$CONF.old"
rm -f "$CONF"

echo "[4/5] regenerating entries (limine-install + mkinitcpio, this takes a moment)"
restore_previous() {
    echo "ERROR: $1" >&2
    if [ -f "$CONF" ]; then
        cp -a "$CONF" "$BK/limine.conf.generated"
        echo "Rejected config kept at $BK/limine.conf.generated" >&2
    fi
    if [ -f "$BK/boot/limine.conf" ]; then
        cp -a "$BK/boot/limine.conf" "$CONF"
        chmod 644 "$CONF" 2>/dev/null || true
        echo "Restored the previous $CONF so the machine still boots." >&2
    fi
    exit 1
}
if ! limine-update; then
    restore_previous "limine-update failed"
fi

echo "[5/5] verifying"

fail=0
[ -s "$CONF" ] || { echo "  - $CONF is missing or empty" >&2; fail=1; }

# Top-level menu entry. limine-entry-tool writes these at column 0.
if ! grep -qE '^[[:space:]]*/[^/]' "$CONF"; then
    echo "  - no top-level menu entry found" >&2
    fail=1
fi

# Kernel sub-entry. limine-entry-tool indents these (2 spaces by default),
# so do NOT anchor to column 0: '  //linux' is valid and expected.
if ! grep -qE '^[[:space:]]*//[^/]' "$CONF"; then
    echo "  - no '//kernel' sub-entry found" >&2
    fail=1
fi

# Every boot(): path used by an entry must really exist on the ESP.
# Paths may carry a '#<blake2b>' suffix for Limine's integrity check.
while IFS= read -r p; do
    case "$p" in
    "boot():/"*) ;;
    *) continue ;;
    esac
    rel=${p#boot():/}
    rel=${rel%%#*}
    if [ ! -f "$ESP/$rel" ]; then
        echo "  - missing boot file: $ESP/$rel (from '$p')" >&2
        fail=1
    fi
done < <(sed -n 's/^[[:space:]]*\(module_path\|path\):[[:space:]]*//p' "$CONF")

if [ "$fail" -ne 0 ]; then
    restore_previous "generated config failed verification"
fi

grep -nE '^[[:space:]]*/' "$CONF"
echo
echo "OK. Backup in $BK. Reboot to test."
echo "Do NOT re-run the Aequalyn installer's apply.sh afterwards: it recreates the flat config and the EFI-side copies."
