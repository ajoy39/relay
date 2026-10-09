#!/usr/bin/env bash
# verify_vendor.sh <trial> — a trial's dependencies must be exactly what it was
# given: vendor/ AND the manifest that describes it (composer.json, composer.lock).
# In a sealed trial, a change to either is a finding, not a pass.
#
# vendor/: Linux sealed trials get a read-only bind mount, which cannot change.
# macOS trials get an APFS clone sealed with chmod a-w — and a trial can undo a
# chmod. So this refuses any inode under vendor/ whose ctime is newer than the
# baseline new_trial.sh stamped. ctime moves on every write, chmod, add, delete
# and rename, and an unprivileged process cannot set it backwards, so backdating
# an edit with `touch -r` does not hide it.
#
# Manifest: a failed `composer require` against a sealed vendor does NOT leave
# the trial clean. Composer writes composer.json and the lock file, then fails at
# mkdir, and does not revert them (measured, Composer 2.8.12). vendor/ is intact,
# so a vendor-only check passed it. Both files are compared with the trial
# worktree's HEAD.
#
# Writable trials (created with VENDOR_WRITABLE=1) are reported, not judged.
# Exit: 0 intact (or writable), 1 changed, 3 BROKEN — a check that cannot
# establish its baseline must never report a pass.
set -euo pipefail
NAME="${1:?usage: verify_vendor.sh <trial>}"
: "${LAB_ROOT:?set LAB_ROOT — see the experiment README, Rebuilding the lab}"
DIR="$LAB_ROOT/trials/$NAME"
BASELINE="$LAB_ROOT/trials/$NAME.vendor-baseline"
broken() { echo "VENDOR: BROKEN — $1" >&2; exit 3; }

[ -f "$BASELINE" ]   || broken "no baseline at $BASELINE (not created by new_trial.sh?)"
[ -d "$DIR/vendor" ] || broken "$DIR/vendor is missing"
MODE="$(sed -n 's/^mode=//p' "$BASELINE")"
case "$MODE" in sealed|writable) ;; *) broken "baseline names no known mode ('$MODE')" ;; esac
git -C "$DIR" rev-parse --verify -q HEAD >/dev/null 2>&1 \
  || broken "$DIR is not a git worktree, so the manifest has no baseline"

# Into a file, not a pipe into head: a find error must be BROKEN, never "intact".
OUT="$(mktemp)"; trap 'rm -f "$OUT"' EXIT
find "$DIR/vendor" -cnewer "$BASELINE" -print > "$OUT" 2>/dev/null \
  || broken "could not walk $DIR/vendor"
vendor_changed="$(wc -l < "$OUT" | tr -d ' ')"

manifest_changed=""
for f in composer.json composer.lock; do
  git -C "$DIR" ls-files --error-unmatch -- "$f" >/dev/null 2>&1 \
    || broken "$f is not tracked in the app repo, so it has no baseline"
  rc=0; git -C "$DIR" diff --quiet HEAD -- "$f" >/dev/null 2>&1 || rc=$?
  case "$rc" in
    0) ;;
    1) manifest_changed="${manifest_changed:+$manifest_changed }$f" ;;
    *) broken "git diff on $f exited $rc" ;;
  esac
done

if [ "$MODE" = "writable" ]; then
  echo "VENDOR: writable by design — not judged ($vendor_changed path(s) changed; manifest: ${manifest_changed:-unchanged})"
  exit 0
fi

status=0
if [ "$vendor_changed" -eq 0 ]; then
  echo "VENDOR: intact"
else
  echo "VENDOR: MODIFIED ($vendor_changed path(s) changed after the baseline)"
  head -20 "$OUT" | sed 's/^/  /'
  status=1
fi
if [ -z "$manifest_changed" ]; then
  echo "MANIFEST: intact"
else
  echo "MANIFEST: MODIFIED ($manifest_changed differ from the trial's HEAD)"
  status=1
fi
exit "$status"
