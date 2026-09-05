#!/usr/bin/env bash
set -euo pipefail
NAME="${1:?usage: rm_trial.sh <name>}"
DIR=/home/user/lab/trials/$NAME
mountpoint -q "$DIR/vendor" && umount "$DIR/vendor"
rm -rf "$DIR"
git -C /home/user/lab/app worktree prune
