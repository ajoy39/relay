#!/usr/bin/env bash
# new_trial.sh <name> — build an isolated checkout of the app for one trial.
# Prints the trial directory on stdout. vendor/ is the trial's own unwritable
# directory (below); the published CP assets are symlinked; everything else the
# trial may write to is its own.
set -euo pipefail
NAME="${1:?usage: new_trial.sh <name>}"
: "${LAB_ROOT:?set LAB_ROOT — see the experiment README, Rebuilding the lab}"
APP="$LAB_ROOT/app"
DIR="$LAB_ROOT/trials/$NAME"
SEAL="$LAB_ROOT/trials/$NAME.vendor-sealed"
OS="$(uname -s)"
case "$OS" in Linux|Darwin) ;; *)
  echo "new_trial.sh: no vendor isolation implemented for $OS (Linux: bind mount; macOS: APFS clone)." >&2
  exit 2 ;;
esac

[ -e "$DIR" ] && { echo "trial $NAME already exists" >&2; exit 1; }

git -C "$APP" worktree add --detach --quiet "$DIR" main

# vendor/ must be (a) the trial's OWN directory, never a symlink — composer
# resolves its base directory from the realpath of vendor/composer, so a
# symlinked vendor autoloads the master app's classes instead of the trial's —
# and (b) unwritable, which enforces the ticket's "no changes to vendor/**".
if [ "$OS" = "Linux" ]; then
  # Read-only bind mount: shares the master's files and cannot be written at all.
  mkdir -p "$DIR/vendor"
  mount --bind -o ro "$APP/vendor" "$DIR/vendor"
else
  # APFS clone: copy-on-write, so near-free on disk, and the trial's own realpath.
  # Unlike a read-only mount it is writable, so it is sealed (chmod a-w, which
  # makes an accidental write fail loudly) and verify_vendor.sh refuses any
  # trial whose vendor/ changed after the seal. Unseal before deleting: rm_trial.sh.
  cp -cR "$APP/vendor" "$DIR/vendor"
  chmod -R a-w "$DIR/vendor"
fi
mkdir -p "$DIR/public/vendor"
ln -s "$APP/public/vendor/statamic" "$DIR/public/vendor/statamic"
cp "$APP/.env" "$DIR/.env"

mkdir -p "$DIR/storage/framework/cache/data" \
         "$DIR/storage/framework/sessions" \
         "$DIR/storage/framework/views" \
         "$DIR/storage/logs" \
         "$DIR/bootstrap/cache"

cp "$LAB_ROOT/spec/pristine.sqlite" "$DIR/database/database.sqlite"

# Stamp the seal LAST, a second after the chmod, so nothing set up here can
# look newer than it. verify_vendor.sh compares vendor/ ctimes against it.
sleep 1
touch "$SEAL"

echo "$DIR"
