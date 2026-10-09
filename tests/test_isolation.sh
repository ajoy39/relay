#!/usr/bin/env bash
# test_isolation.sh — the macOS trial-isolation branch: each trial gets its own
# real, sealed vendor/, and any change to it is caught — including changes made
# to look as if they never happened. On a Mac this runs Apple's real clonefile;
# elsewhere the macOS branch is simulated (see lib.sh, darwin_branch).
. "$(dirname "$0")/lib.sh"
non_root; need git
S="$REPO/experiments/statamic-blueprint-revisions/scripts"; B="$BASH_UT"
darwin_branch
make_lab "$WORK/lab"; A="$LAB_ROOT/app"; T="$LAB_ROOT/trials"
vv() { "$B" "$S/verify_vendor.sh" "$1" >/dev/null 2>&1; }

echo "== a fresh trial"
D="$("$B" "$S/new_trial.sh" t1 2>&1)"; chk "new_trial succeeds" "$?" "0"
chk "vendor/ is a real directory, not a symlink" "$( [ -d "$D/vendor" ] && [ ! -L "$D/vendor" ] && echo yes)" "yes"
chk "contents identical to the master's" "$(diff -r "$A/vendor" "$D/vendor" >/dev/null && echo same)" "same"
case "$(realdir "$D/vendor/composer")" in "$(realdir "$D")"/*) r=inside ;; *) r=outside ;; esac
chk "composer's realpath resolves inside the TRIAL (what a symlink gets wrong)" "$r" "inside"
chk "baseline stamped, mode=sealed" "$(cat "$T/t1.vendor-baseline")" "mode=sealed"
( echo x >> "$D/vendor/autoload.php" ) 2>/dev/null; chk "writing vendor fails loudly (sealed)" "$?" "1"
vv t1; chk "fresh trial -> intact (0)" "$?" "0"
cat $(find "$D/vendor" -type f) >/dev/null
vv t1; chk "reading every file -> still intact (no false positive)" "$?" "0"

echo "== tampering is caught"
for n in t2 t3 t4 t5 t6; do "$B" "$S/new_trial.sh" $n >/dev/null 2>&1; done
chmod u+w "$T/t2/vendor/autoload.php"; echo evil >> "$T/t2/vendor/autoload.php"
vv t2; chk "edit a file -> MODIFIED (1)" "$?" "1"
chmod u+w "$T/t3/vendor/autoload.php"; echo evil >> "$T/t3/vendor/autoload.php"; touch -r "$A/vendor/autoload.php" "$T/t3/vendor/autoload.php"
vv t3; chk "edit + backdate mtime with touch -r -> still MODIFIED (ctime)" "$?" "1"
chmod u+w "$T/t4/vendor/composer"; echo '<?php' > "$T/t4/vendor/composer/injected.php"
vv t4; chk "add a file -> MODIFIED" "$?" "1"
chmod u+w "$T/t5/vendor/statamic/cms/src"; rm "$T/t5/vendor/statamic/cms/src/Cms.php"
vv t5; chk "delete a file -> MODIFIED" "$?" "1"
chmod u+w "$T/t6/vendor/autoload.php"
vv t6; chk "only undo the seal (chmod) -> MODIFIED" "$?" "1"
"$B" "$S/verify_vendor.sh" nosuch >/dev/null 2>&1; chk "no baseline -> BROKEN (3)" "$?" "3"

echo "== teardown"
rm -rf "$T/t6" 2>/dev/null; chk "a plain rm -rf on a sealed trial FAILS (why the unseal matters)" "$?" "1"
"$B" "$S/rm_trial.sh" t6 >/dev/null 2>&1; chk "  ...rm_trial.sh, which unseals first, succeeds" "$?" "0"
for n in t1 t2 t3 t4 t5; do "$B" "$S/rm_trial.sh" $n >/dev/null 2>&1 || echo "  rm_trial $n failed"; done
chk "every trial and baseline removed" "$(ls "$T" | wc -l | tr -d ' ')" "0"
chk "worktrees pruned" "$(git -C "$A" worktree list | wc -l | tr -d ' ')" "1"
finish
