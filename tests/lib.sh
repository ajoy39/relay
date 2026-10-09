# tests/lib.sh — shared by every suite. Sourced, never run.
#
# Deliberately bash-3.2-clean: on macOS these suites run under /bin/bash, which
# is 3.2, so the harness that tests portability must itself be portable. No GNU
# flags either (sed -i, readlink -f, md5sum): see subst() and sha256_files().
pass=0; fail=0
chk()   { if [ "$2" = "$3" ]; then echo "PASS  $1"; pass=$((pass+1)); else echo "FAIL  $1   (expected [$3] got [$2])"; fail=$((fail+1)); fi; }
has()   { if printf '%s' "$2" | grep -qF -- "$3"; then echo "PASS  $1"; pass=$((pass+1)); else echo "FAIL  $1   (missing: $3)"; printf '%s\n' "$2" | sed 's/^/        | /' | head -12; fail=$((fail+1)); fi; }
hasnt() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "FAIL  $1   (unexpected: $3)"; fail=$((fail+1)); else echo "PASS  $1"; pass=$((pass+1)); fi; }
# Exit 3 = BROKEN (the suite could not run), 4 = not applicable on this host.
# Neither is a pass: run.sh reports them separately.
broken() { echo "BROKEN  $*" >&2; exit 3; }
na()     { echo "NOT APPLICABLE  $*"; exit 4; }
need()   { for c in "$@"; do command -v "$c" >/dev/null 2>&1 || broken "needs '$c' on PATH"; done; }
finish() { echo; echo "RESULT: $pass passed, $fail failed"; [ "$fail" -eq 0 ]; }

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
BASH_UT="${BASH_UT:-/bin/bash}"   # the bash the scripts under test run in
[ -x "$BASH_UT" ] || broken "BASH_UT=$BASH_UT is not executable"
bash_ut_version() { "$BASH_UT" -c 'echo "${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}"'; }

# Commits made by the scripts under test (and by the stand-in implementer)
# must not depend on, or touch, anyone's git identity.
export GIT_AUTHOR_NAME=relaytest GIT_AUTHOR_EMAIL=relaytest@example.test
export GIT_COMMITTER_NAME=relaytest GIT_COMMITTER_EMAIL=relaytest@example.test

WORK="$(mktemp -d "${TMPDIR:-/tmp}/relaytest.XXXXXX")"
cleanup() { chmod -R u+w "$WORK" 2>/dev/null; rm -rf "$WORK"; }
trap cleanup EXIT

sha256_files() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$@"; else shasum -a 256 "$@"; fi; }
subst() { perl -pi -e "$1" "$2"; }      # in-place edit; BSD and GNU sed -i differ
realdir() { (cd "$1" && pwd -P); }       # readlink -f is not on older macOS

# toolbox <dir> [exclude...] — a PATH directory of wrappers for the commands
# the scripts use, minus the excluded ones. How a suite removes ruff (say) from
# PATH without also removing everything that shares its directory. `bash` is
# wired to BASH_UT, so scripts calling scripts stay in the bash under test.
toolbox() {
  tb="$1"; shift; mkdir -p "$tb"
  for c in bash sh env python3 git grep awk sed tr sort uniq head tail wc cat cp mv rm \
           mkdir ls find basename dirname mktemp touch chmod date sleep cut diff cmp perl \
           shasum sha256sum uname id node composer php xargs ruff mountpoint mount umount; do
    skip=0; for x in "$@"; do [ "$x" = "$c" ] && skip=1; done; [ "$skip" = 1 ] && continue
    if [ "$c" = bash ]; then p="$BASH_UT"; else p="$(command -v "$c" 2>/dev/null)" || continue; fi
    case "$p" in /*) ;; *) continue ;; esac
    printf '#!/bin/sh\nexec "%s" "$@"\n' "$p" > "$tb/$c"; chmod +x "$tb/$c"
  done
}

# A real lab app for the isolation suites: a git repo on main with tracked
# composer.json/composer.lock, a vendor/ the repo ignores, and what
# new_trial.sh copies. With composer available it is a real Composer project
# using local path packages (no network); otherwise placeholder manifests.
make_lab() {
  LAB_ROOT="$1"; export LAB_ROOT; A="$LAB_ROOT/app"
  mkdir -p "$LAB_ROOT/trials" "$LAB_ROOT/spec" "$A/public/vendor/statamic" "$A/database"
  echo db > "$LAB_ROOT/spec/pristine.sqlite"; echo APP_KEY=test > "$A/.env"; touch "$A/database/.gitkeep"
  printf 'vendor/\n.env\npublic/vendor/\n' > "$A/.gitignore"
  if [ "${2:-}" = composer ]; then
    for p in a b; do mkdir -p "$WORK/pkgs/$p/src"; printf '{"name":"acme/%s","version":"1.0.0"}\n' "$p" > "$WORK/pkgs/$p/composer.json"; echo '<?php' > "$WORK/pkgs/$p/src/X.php"; done
    printf '{"repositories":[{"packagist.org":false},{"type":"path","url":"%s/pkgs/*","options":{"symlink":false}}],"require":{}}\n' "$WORK" > "$A/composer.json"
    (cd "$A" && composer require -q acme/a:1.0.0) || broken "could not build the Composer fixture"
  else
    mkdir -p "$A/vendor/composer" "$A/vendor/statamic/cms/src"
    echo '<?php // autoload' > "$A/vendor/autoload.php"
    echo '<?php return [];' > "$A/vendor/composer/autoload_static.php"
    echo '<?php class Cms {}' > "$A/vendor/statamic/cms/src/Cms.php"
    echo '{}' > "$A/composer.json"; echo '{}' > "$A/composer.lock"
  fi
  git -C "$A" init -q -b main && git -C "$A" add -A && git -C "$A" commit -q -m init || broken "could not build the lab app repo"
}

# On macOS the isolation suites exercise the REAL clone (cp -c, clonefile).
# Anywhere else the macOS branch is simulated: `uname` says Darwin and `cp -cR`
# becomes a copy-on-write `cp --reflink`. Said out loud either way.
darwin_branch() {
  host="$(uname -s)"   # read BEFORE the uname shim goes on PATH
  if [ "$host" = Darwin ]; then echo "macOS branch: REAL (cp -c / clonefile)"; return; fi
  mkdir -p "$WORK/shims"
  printf '#!/bin/sh\necho Darwin\n' > "$WORK/shims/uname"
  printf '#!/bin/sh\nif [ "$1" = "-cR" ]; then shift; exec %s -R --reflink=auto "$@"; fi\nexec %s "$@"\n' "$(command -v cp)" "$(command -v cp)" > "$WORK/shims/cp"
  chmod +x "$WORK/shims/uname" "$WORK/shims/cp"; PATH="$WORK/shims:$PATH"; export PATH
  echo "macOS branch: SIMULATED on $host (uname shim + cp --reflink) — run on a Mac to test clonefile"
}
non_root() { [ "$(id -u)" != 0 ] || broken "run as a non-root user: root ignores chmod, so the seal tests would pass for the wrong reason"; }
