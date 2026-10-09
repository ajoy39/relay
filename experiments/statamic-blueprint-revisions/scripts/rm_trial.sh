#!/usr/bin/env bash
set -euo pipefail
NAME="${1:?usage: rm_trial.sh <name>}"
: "${LAB_ROOT:?set LAB_ROOT — see the experiment README, Rebuilding the lab}"
DIR="$LAB_ROOT/trials/$NAME"
# Unmount BEFORE rm -rf: a still-mounted read-only vendor makes rm fail halfway
# and leaves a half-deleted tree that scores as NORESULT (run 07). `mountpoint`
# is Linux-only, as are the bind mounts it checks for.
if command -v mountpoint >/dev/null 2>&1 && mountpoint -q "$DIR/vendor"; then
  umount "$DIR/vendor"
fi
rm -rf "$DIR"
git -C "$LAB_ROOT/app" worktree prune
