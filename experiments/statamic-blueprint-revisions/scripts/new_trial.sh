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
BASELINE="$LAB_ROOT/trials/$NAME.vendor-baseline"
OS="$(uname -s)"
# VENDOR_WRITABLE=1 is for experiments where adding packages is LEGITIMATE: the
# trial gets its own writable vendor/ and verify_vendor.sh reports changes
# instead of failing on them. Default 0 (sealed). Anything else is refused —
# a typo must not silently flip the isolation model.
case "${VENDOR_WRITABLE:-0}" in
  0) MODE=sealed ;;
  1) MODE=writable ;;
  *) echo "new_trial.sh: VENDOR_WRITABLE must be 0 or 1, not '${VENDOR_WRITABLE}'" >&2; exit 2 ;;
esac
case "$OS" in Linux|Darwin) ;; *)
  echo "new_trial.sh: no vendor isolation implemented for $OS (Linux: bind mount; macOS: APFS clone)." >&2
  exit 2 ;;
esac

[ -e "$DIR" ] && { echo "trial $NAME already exists" >&2; exit 1; }

# Its own clone, not a worktree: refs/stash lives in the COMMON git dir, so
# worktrees of one repo share a stash list, and in run 07 trials s045/s046 saw
# other trials' stashed work. --shared borrows the master's objects (cheap; the
# app repo excludes vendor/) while refs, stash included, stay the trial's own.
# No remote: a trial must not be able to push into the master app.
git clone --quiet --shared --branch main "$APP" "$DIR"
git -C "$DIR" remote remove origin
git -C "$DIR" checkout --quiet --detach

# vendor/ must be (a) the trial's OWN directory, never a symlink — composer
# resolves its base directory from the realpath of vendor/composer, so a
# symlinked vendor autoloads the master app's classes instead of the trial's —
# and (b) unwritable, which enforces the ticket's "no changes to vendor/**".
if [ "$OS" = "Linux" ] && [ "$MODE" = "sealed" ]; then
  # Read-only bind mount: shares the master's files and cannot be written at all.
  mkdir -p "$DIR/vendor"
  mount --bind -o ro "$APP/vendor" "$DIR/vendor"
elif [ "$OS" = "Darwin" ]; then
  # APFS clone: copy-on-write, so near-free on disk, and the trial's own realpath.
  # Writes land in this trial's copy only, never the master's or a neighbour's.
  # Sealed mode adds chmod a-w, so an accidental write fails loudly, and
  # verify_vendor.sh refuses any change after the baseline. Unseal before
  # deleting: rm_trial.sh.
  cp -cR "$APP/vendor" "$DIR/vendor"
  if [ "$MODE" = "sealed" ]; then chmod -R a-w "$DIR/vendor"; fi
else
  # Linux, writable: a bind mount would share writes with every trial, so the
  # trial gets its own copy — copy-on-write where the filesystem supports
  # reflinks, a full copy where it does not.
  cp -R --reflink=auto "$APP/vendor" "$DIR/vendor"
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

# Stamp the baseline LAST, a second after the chmod, so nothing set up here can
# look newer than it. Its mtime is the time verify_vendor.sh compares ctimes
# against; its content is the mode, so a trial is always judged by the rules it
# was created under, never by whatever VENDOR_WRITABLE says at scoring time.
sleep 1
printf 'mode=%s\n' "$MODE" > "$BASELINE"

echo "$DIR"
