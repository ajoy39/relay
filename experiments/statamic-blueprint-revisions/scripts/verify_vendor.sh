#!/usr/bin/env bash
# verify_vendor.sh <trial> — the trial's vendor/ must be exactly what it was given.
# A trial that changes vendor/ is a finding, not a pass.
#
# Linux trials get a read-only bind mount, which cannot change. macOS trials get
# an APFS clone sealed with chmod a-w — and a trial can undo a chmod. So this
# refuses any inode under vendor/ whose ctime is newer than the seal stamped by
# new_trial.sh. ctime moves on every write, chmod, add, delete and rename, and an
# unprivileged process cannot set it backwards, so backdating mtime with
# `touch` does not hide a change.
set -euo pipefail
NAME="${1:?usage: verify_vendor.sh <trial>}"
: "${LAB_ROOT:?set LAB_ROOT — see the experiment README, Rebuilding the lab}"
DIR="$LAB_ROOT/trials/$NAME"
SEAL="$LAB_ROOT/trials/$NAME.vendor-sealed"
[ -f "$SEAL" ]        || { echo "VENDOR: BROKEN — no seal at $SEAL (not created by new_trial.sh?)" >&2; exit 3; }
[ -d "$DIR/vendor" ]  || { echo "VENDOR: BROKEN — $DIR/vendor is missing" >&2; exit 3; }
# Into a file, not a pipe into head: a find error must be BROKEN, never "intact".
OUT="$(mktemp)"; trap 'rm -f "$OUT"' EXIT
find "$DIR/vendor" -cnewer "$SEAL" -print > "$OUT" 2>/dev/null \
  || { echo "VENDOR: BROKEN — could not walk $DIR/vendor" >&2; exit 3; }
if [ ! -s "$OUT" ]; then
  echo "VENDOR: intact"
else
  echo "VENDOR: MODIFIED ($(wc -l < "$OUT" | tr -d ' ') path(s) changed after the seal)"
  head -20 "$OUT" | sed 's/^/  /'
  exit 1
fi
