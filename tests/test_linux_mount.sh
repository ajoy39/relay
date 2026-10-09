#!/usr/bin/env bash
# test_linux_mount.sh — the Linux branch: a read-only bind mount for sealed
# trials, a per-trial copy for writable ones. Needs Linux, root and the
# capability to bind-mount (a cloud sandbox has it; macOS has no bind mounts).
. "$(dirname "$0")/lib.sh"
[ "$(uname -s)" = Linux ] || na "Linux only — macOS trials use APFS clones (test_isolation.sh)"
[ "$(id -u)" = 0 ]        || na "needs root to bind-mount"
need git mount umount mountpoint
mkdir -p "$WORK/m/src" "$WORK/m/dst"
mount --bind -o ro "$WORK/m/src" "$WORK/m/dst" 2>/dev/null || na "this host cannot bind-mount"
umount "$WORK/m/dst"
S="$REPO/experiments/statamic-blueprint-revisions/scripts"; B="$BASH_UT"
make_lab "$WORK/lab"; A="$LAB_ROOT/app"; T="$LAB_ROOT/trials"
cleanup_mounts() { for d in "$T"/*/vendor; do mountpoint -q "$d" 2>/dev/null && umount "$d"; done; cleanup; }
trap cleanup_mounts EXIT

D="$("$B" "$S/new_trial.sh" L1 2>&1)"
chk "sealed Linux trial: vendor is a bind mount" "$(mountpoint -q "$D/vendor" && echo mount)" "mount"
out="$( (echo x >> "$D/vendor/autoload.php") 2>&1 )"; has "  ...read-only even to root" "$out" "Read-only file system"
"$B" "$S/verify_vendor.sh" L1 >/dev/null 2>&1; chk "  ...verify -> intact" "$?" "0"
VENDOR_WRITABLE=1 "$B" "$S/new_trial.sh" L2 >/dev/null 2>&1
chk "writable Linux trial: its own copy, not a mount" "$(mountpoint -q "$T/L2/vendor" && echo mount || echo copy)" "copy"
echo x > "$T/L2/vendor/added.php"; chk "  ...a write lands in L2 only" "$( [ -e "$A/vendor/added.php" ] && echo leaked || echo isolated)" "isolated"
out="$("$B" "$S/verify_vendor.sh" L2 2>&1)"; has "  ...verify reports, does not judge" "$out" "writable by design"
for n in L1 L2; do "$B" "$S/rm_trial.sh" $n >/dev/null 2>&1 || echo "  rm_trial $n failed"; done
chk "teardown: trials removed" "$(ls "$T" | wc -l | tr -d ' ')" "0"
chk "teardown: no mounts left behind" "$(grep -c " $T/" /proc/mounts)" "0"
finish
