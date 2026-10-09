#!/usr/bin/env bash
# test_vendor_manifest.sh — real `composer require` inside real trials.
# Sealed: the install fails, but Composer leaves composer.json/composer.lock
# rewritten and does not revert them — verify_vendor.sh must fail the trial on
# the manifest even though vendor/ is untouched. Writable (VENDOR_WRITABLE=1):
# the package lands in that trial alone, and is reported rather than judged.
. "$(dirname "$0")/lib.sh"
non_root; need git php composer
export COMPOSER_HOME="$WORK/.composer" COMPOSER_NO_INTERACTION=1
S="$REPO/experiments/statamic-blueprint-revisions/scripts"; B="$BASH_UT"
darwin_branch
make_lab "$WORK/lab" composer; A="$LAB_ROOT/app"; T="$LAB_ROOT/trials"
mk() { "$B" "$S/new_trial.sh" "$@" >/dev/null 2>&1; }; vv() { "$B" "$S/verify_vendor.sh" "$@" 2>&1; }
pkgs() { ls "$1/vendor/acme" | tr '\n' ' '; }

echo "== sealed (the default)"
mk s1; out="$(vv s1)"; chk "fresh sealed trial -> 0" "$?" "0"; has "  ...vendor and manifest both intact" "$out" "MANIFEST: intact"
mk s2; (cd "$T/s2" && composer require acme/b:1.0.0 >/dev/null 2>&1); chk "composer require in a sealed trial -> composer fails" "$?" "1"
out="$(vv s2)"; rc=$?
chk "  ...verify fails the trial (was: passed it)" "$rc" "1"
has "  ...vendor really is untouched" "$out" "VENDOR: intact"
has "  ...the dirty manifest is what is caught" "$out" "MANIFEST: MODIFIED (composer.json composer.lock"
mk s3; echo '{"x":1}' > "$T/s3/composer.json"; vv s3 >/dev/null; chk "hand-edited composer.json -> 1" "$?" "1"
mk s4; chmod -R u+w "$T/s4/vendor"; (cd "$T/s4" && composer require -q acme/b:1.0.0); out="$(vv s4)"; rc=$?
chk "unseal + require -> 1" "$rc" "1"; has "  ...flags vendor" "$out" "VENDOR: MODIFIED"; has "  ...and manifest" "$out" "MANIFEST: MODIFIED"
VENDOR_WRITABLE=1 "$B" "$S/verify_vendor.sh" s2 >/dev/null 2>&1
chk "mode fixed at creation: VENDOR_WRITABLE=1 at scoring cannot excuse s2" "$?" "1"

echo "== writable (VENDOR_WRITABLE=1)"
VENDOR_WRITABLE=1 mk w1
( echo x > "$T/w1/vendor/probe" ) 2>/dev/null; chk "vendor is writable" "$?" "0"; rm -f "$T/w1/vendor/probe"
(cd "$T/w1" && composer require -q acme/b:1.0.0); chk "composer require succeeds" "$?" "0"
chk "  ...package lands in this trial"  "$(pkgs "$T/w1")" "a b "
chk "  ...master untouched"             "$(pkgs "$A")"     "a "
chk "  ...sealed neighbour untouched"   "$(pkgs "$T/s1")"  "a "
out="$(vv w1)"; chk "verify -> 0 (reported, not judged)" "$?" "0"; has "  ...but says what changed" "$out" "manifest: composer.json composer.lock"
VENDOR_WRITABLE=yes "$B" "$S/new_trial.sh" bad >/dev/null 2>&1; chk "VENDOR_WRITABLE=yes -> refused (2)" "$?" "2"
chk "  ...created nothing" "$( [ -e "$T/bad" ] && echo made || echo none)" "none"

echo "== BROKEN, never a pass"
mk b1; echo mode=whatever > "$T/b1.vendor-baseline"; vv b1 >/dev/null; chk "unknown mode -> 3" "$?" "3"
mk b2; git -C "$T/b2" rm -q --cached composer.lock; vv b2 >/dev/null; chk "composer.lock untracked -> 3" "$?" "3"
mk b3; rm "$T/b3/.git"; vv b3 >/dev/null; chk "not a git worktree -> 3" "$?" "3"

echo "== teardown"
for n in s1 s2 s3 s4 w1 b1 b2 b3; do "$B" "$S/rm_trial.sh" $n >/dev/null 2>&1 || echo "  rm_trial $n failed"; done
chk "every trial and baseline removed" "$(ls "$T" | wc -l | tr -d ' ')" "0"
git -C "$A" worktree prune; chk "worktrees pruned" "$(git -C "$A" worktree list | wc -l | tr -d ' ')" "1"
finish
