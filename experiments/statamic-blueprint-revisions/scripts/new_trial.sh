#!/usr/bin/env bash
# new_trial.sh <name> — build an isolated checkout of the app for one trial.
# Prints the trial directory on stdout. Heavy, immutable directories (vendor,
# the published CP assets) are symlinked; everything the trial may write to is
# its own.
set -euo pipefail
NAME="${1:?usage: new_trial.sh <name>}"
: "${LAB_ROOT:?set LAB_ROOT — see the experiment README, Rebuilding the lab}"
APP="$LAB_ROOT/app"
DIR="$LAB_ROOT/trials/$NAME"

# Trial isolation rests on a READ-ONLY bind mount of vendor/ (below). macOS has
# no bind mounts, and a symlink is not a substitute: composer resolves its base
# directory from the realpath, so a symlinked vendor autoloads the master app's
# classes. Refuse before creating anything rather than degrade isolation quietly.
if [ "$(uname -s)" != "Linux" ]; then
  echo "new_trial.sh: trial isolation needs a read-only bind mount of vendor/, which $(uname -s) does not have." >&2
  echo "Not falling back to a symlink (wrong autoloading). See the experiment README, Rebuilding the lab." >&2
  exit 2
fi

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

cp "$LAB_ROOT/spec/pristine.sqlite" "$DIR/database/database.sqlite"

echo "$DIR"
