#!/usr/bin/env bash
set -euo pipefail
NAME="${1:?usage: rm_trial.sh <name>}"
: "${LAB_ROOT:?set LAB_ROOT — see the experiment README, Rebuilding the lab}"
DIR="$LAB_ROOT/trials/$NAME"
# Unmount or unseal BEFORE rm -rf. A still-mounted read-only vendor (Linux) or a
# clone sealed with chmod a-w (macOS) makes rm fail halfway and leaves a
# half-deleted tree that scores as NORESULT (run 07). `mountpoint` is
# Linux-only, as are the bind mounts it checks for.
#
# Run 08: the trial user and the gate user also create files here, and some
# tools (artisan, Laravel's cache) make directories with fixed modes that
# ignore the umask, so the owner can't delete them. Where the lab's wrappers
# are installed, each user first opens up the files it owns in this trial.
# Best effort: a failure here shows up as rm's error below. The `sudo` rules
# name these exact paths, so this only works for LAB_ROOT=/Users/Shared/lab.
BIN="$LAB_ROOT/bin"
if [ -d "$DIR" ] && [ -x "$BIN/lab-git" ] && [ -x "$BIN/run-trial" ]; then
  sudo -n -u labgate "$BIN/lab-git" release "$NAME" 2>/dev/null || true
  sudo -n -u labtrial "$BIN/run-trial" --release "$NAME" 2>/dev/null || true
fi
if command -v mountpoint >/dev/null 2>&1 && mountpoint -q "$DIR/vendor"; then
  umount "$DIR/vendor"
elif [ -d "$DIR/vendor" ]; then
  chmod -R u+w "$DIR/vendor"
fi
rm -rf "$DIR" "$LAB_ROOT/trials/$NAME.vendor-baseline" "$LAB_ROOT/trials/$NAME.prompt.md"
# Trials are clones now; prune clears any worktree a pre-run-08 lab left behind.
git -C "$LAB_ROOT/app" worktree prune
