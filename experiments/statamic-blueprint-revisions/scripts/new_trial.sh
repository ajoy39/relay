#!/usr/bin/env bash
# new_trial.sh <name> — build an isolated checkout of the app for one trial.
# Prints the trial directory on stdout. Heavy, immutable directories (vendor,
# the published CP assets) are symlinked; everything the trial may write to is
# its own.
set -euo pipefail
NAME="${1:?usage: new_trial.sh <name>}"
APP=/home/user/lab/app
DIR=/home/user/lab/trials/$NAME

[ -e "$DIR" ] && { echo "trial $NAME already exists" >&2; exit 1; }

git -C "$APP" worktree add --detach --quiet "$DIR" main

# vendor is bind-mounted read-only, not symlinked: composer resolves its base
# directory from the realpath of vendor/composer, so a symlink would make the
# trial autoload the master app's classes instead of its own. Read-only also
# enforces the ticket's "no changes to vendor/**" invariant mechanically.
mkdir -p "$DIR/vendor"
mount --bind -o ro "$APP/vendor" "$DIR/vendor"
mkdir -p "$DIR/public/vendor"
ln -s "$APP/public/vendor/statamic" "$DIR/public/vendor/statamic"
cp "$APP/.env" "$DIR/.env"

mkdir -p "$DIR/storage/framework/cache/data" \
         "$DIR/storage/framework/sessions" \
         "$DIR/storage/framework/views" \
         "$DIR/storage/logs" \
         "$DIR/bootstrap/cache"

cp /home/user/lab/spec/pristine.sqlite "$DIR/database/database.sqlite"

echo "$DIR"
