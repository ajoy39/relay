#!/usr/bin/env bash
# test_scripts.sh — the ticket loop and the experiment scripts: does each gate
# report only what it measured, and does everything run under macOS's bash 3.2?
# Checked against the pre-fix code on 2026-10-09: 33 of these assertions failed
# there, each on a real defect. Set BASH_UT to a bash 3.2 to test portability on
# a host whose own bash is newer.
. "$(dirname "$0")/lib.sh"
need git python3 ruff node perl
python3 -m pytest --version >/dev/null 2>&1 || broken "python3 cannot import pytest"
v="$(bash_ut_version)"; echo "bash under test: $v"
case "$v" in 3.2) ;; *) echo "NOTE: not bash 3.2 — portability to macOS /bin/bash is NOT being tested on this run" ;; esac
B="$BASH_UT"; REALPY="$(command -v python3)"

cp -pR "$REPO" "$WORK/rt"; cd "$WORK/rt" || broken "could not copy the repo"
rm -rf .worktrees
mkdir -p "$WORK/shims"

echo "== check_ticket.sh: BROKEN is not RED; named-test check runs under 3.2"
REALTEST="$(ls parser/tests/test_*.py | head -1)"; T2="$(ls parser/tests/test_*.py | sed -n 2p)"
cat > tickets/9999-test.md <<TICKET
# Ticket 9999 — synthetic

**Status**: ready
**Scope (writable paths)**: parser/src/
**Acceptance command**: \`scripts/gates.sh\`
**Dispatch budget**: 3 rounds

## Goal
A synthetic ticket for exercising the preflight.
## Structure and dependencies
None beyond the parser package.
## Invariants
Existing tests keep passing.
## Non-goals
Nothing else.
## Specification
See the named tests.
## Acceptance
The named tests pass: $REALTEST and parser/tests/test_does_not_exist.py
## How to run the tests
scripts/gates.sh
## If the contract is broken
Say so in the final message.
TICKET
mv scripts/gates.sh scripts/gates.real.sh
for rc in 0 1 3 7; do
  printf '#!/usr/bin/env bash\nexit %s\n' "$rc" > scripts/gates.sh; chmod +x scripts/gates.sh
  out="$("$B" scripts/check_ticket.sh tickets/9999-test.md 2>&1)"; prc=$?
  case $rc in
    0) has "gates exit 0 -> GREEN refused" "$out" "gates are already GREEN" ;;
    1) has "gates exit 1 -> RED accepted" "$out" "ok    gates are RED"; chk "RED + a missing named test -> preflight still fails" "$prc" "1" ;;
    3) has "gates exit 3 -> BROKEN, not RED" "$out" "gates are BROKEN"; hasnt "  ...and never reported as RED" "$out" "gates are RED" ;;
    7) has "gates exit 7 -> unexpected, refused" "$out" "gates exited 7" ;;
  esac
done
has   "named-test check RUNS (was skipped under 3.2)" "$out" "test file present and collectable: $REALTEST"
has   "  ...and catches a missing named file"          "$out" "ticket names parser/tests/test_does_not_exist.py but no such file"
hasnt "  ...with no bash-4 errors"                      "$out" "command not found"
hasnt "  ...and no unbound-variable errors"            "$out" "unbound variable"
subst 's# and parser/tests/test_does_not_exist\.py##' tickets/9999-test.md
printf '#!/usr/bin/env bash\nexit 1\n' > scripts/gates.sh
"$B" scripts/check_ticket.sh tickets/9999-test.md >/dev/null 2>&1; chk "clean ticket + RED gates -> PASS" "$?" "0"
subst "s#The named tests pass: .*#The named tests pass: $REALTEST and $T2#" tickets/9999-test.md
out="$("$B" scripts/check_ticket.sh tickets/9999-test.md 2>&1)"
chk "two named files -> BOTH checked (loop not starved by stdin)" "$(echo "$out" | grep -c 'present and collectable')" "2"
subst 's#The named tests pass: .*#The behaviour in the spec holds.#' tickets/9999-test.md
out="$("$B" scripts/check_ticket.sh tickets/9999-test.md 2>&1)"; has "no named tests -> empty-list path works" "$out" "no test files named in ticket"
mv scripts/gates.real.sh scripts/gates.sh; rm tickets/9999-test.md

echo "== gates.sh: missing tooling and unmeasured runs are BROKEN"
out="$("$B" scripts/gates.sh 2>&1)"; echo "      (this repo's real suite: exit $?, $(echo "$out" | grep -E '^GATES:'))"
toolbox "$WORK/noruff" ruff
"$B" -c 'PATH="$1"; "$2" scripts/gates.sh' _ "$WORK/noruff" "$B" >/dev/null 2>&1; chk "no ruff -> 3 (was: skipped, could still pass)" "$?" "3"
printf '#!/bin/sh\nif [ "$1" = "-m" ] && [ "$2" = "pytest" ]; then echo "No module named pytest" >&2; exit 1; fi\nexec "%s" "$@"\n' "$REALPY" > "$WORK/shims/python3"; chmod +x "$WORK/shims/python3"
PATH="$WORK/shims:$PATH" "$B" scripts/gates.sh >/dev/null 2>&1; chk "no pytest -> 3" "$?" "3"; rm "$WORK/shims/python3"
printf '#!/bin/sh\nexit 2\n' > "$WORK/shims/ruff"; chmod +x "$WORK/shims/ruff"
PATH="$WORK/shims:$PATH" "$B" scripts/gates.sh >/dev/null 2>&1; chk "ruff config error (2) -> BROKEN, not RED" "$?" "3"; rm "$WORK/shims/ruff"
printf 'def test_deliberately_red():\n    assert False\n' > parser/tests/test_zz_red.py
out="$("$B" scripts/gates.sh 2>&1)"; chk "a failing test -> RED (1)" "$?" "1"; has "  ...prints GATES: RED" "$out" "GATES: RED"
rm parser/tests/test_zz_red.py
mv parser/tests parser/tests.bak; mkdir parser/tests
"$B" scripts/gates.sh >/dev/null 2>&1; chk "no tests collected (pytest 5) -> BROKEN, not RED" "$?" "3"
rm -rf parser/tests; mv parser/tests.bak parser/tests

E=experiments/statamic-blueprint-revisions
echo "== experiment scripts: LAB_ROOT, and portable without GNU tools"
out="$(env -u LAB_ROOT "$B" $E/spec/gate.sh 2>&1)"; chk "gate.sh, LAB_ROOT unset -> 3 BROKEN (never 1 RED)" "$?" "3"; has "  ...says so" "$out" "LAB_ROOT is not set"
for s in new_trial rm_trial render_arm verify_spec verify_vendor; do
  out="$(env -u LAB_ROOT "$B" $E/scripts/$s.sh x y z 2>&1)"; rc=$?
  if [ $rc -ne 0 ]; then has "$s.sh refuses without LAB_ROOT" "$out" "LAB_ROOT"; else chk "$s.sh refuses without LAB_ROOT" "$rc" "nonzero"; fi
done
L="$WORK/lab"; mkdir -p "$L/trials" "$L/reference"
printf '#!/bin/sh\necho FreeBSD\n' > "$WORK/shims/uname"; chmod +x "$WORK/shims/uname"
out="$(LAB_ROOT="$L" PATH="$WORK/shims:$PATH" "$B" $E/scripts/new_trial.sh t1 2>&1)"; chk "new_trial.sh on an unsupported OS -> refuses (2)" "$?" "2"
has "  ...names both supported mechanisms" "$out" "Linux: bind mount; macOS: APFS clone"
chk "  ...and created nothing" "$(ls "$L/trials" | wc -l | tr -d ' ')" "0"
rm "$WORK/shims/uname"
mkdir -p "$L/spec/arms"; cp $E/spec/*.js $E/spec/*.sh $E/spec/*.php "$L/spec/"; cp $E/spec/arms/* "$L/spec/arms/"
LAB_ROOT="$L" "$B" $E/scripts/verify_spec.sh >/dev/null 2>&1; chk "verify_spec, no checksum file -> BROKEN 3 (was: TAMPERED)" "$?" "3"
(cd "$L/spec" && sha256_files *.js *.sh *.php arms/* > ../reference/spec.sha256)
LAB_ROOT="$L" "$B" $E/scripts/verify_spec.sh >/dev/null 2>&1; chk "verify_spec intact -> 0" "$?" "0"
echo "// edit" >> "$L/spec/gate.spec.js"
out="$(LAB_ROOT="$L" "$B" $E/scripts/verify_spec.sh 2>&1)"; chk "verify_spec tampered -> 1" "$?" "1"; has "  ...names the file" "$out" "gate.spec.js"
toolbox "$WORK/nosha" sha256sum
"$B" -c 'PATH="$1"; LAB_ROOT="$2" "$3" "$4"' _ "$WORK/nosha" "$L" "$B" "$E/scripts/verify_spec.sh" >/dev/null 2>&1
chk "no sha256sum (macOS): shasum fallback still detects tamper" "$?" "1"
(cd "$L/spec" && sha256_files *.js *.sh *.php arms/* > ../reference/spec.sha256)
"$B" -c 'PATH="$1"; LAB_ROOT="$2" "$3" "$4"' _ "$WORK/nosha" "$L" "$B" "$E/scripts/verify_spec.sh" >/dev/null 2>&1
chk "  ...and passes an intact spec" "$?" "0"
git init -q -b main "$L/app" && git -C "$L/app" commit -q --allow-empty -m init && git -C "$L/app" worktree add -q --detach "$L/trials/t2" && mkdir -p "$L/trials/t2/vendor"
LAB_ROOT="$L" "$B" $E/scripts/rm_trial.sh t2 >/dev/null 2>&1; chk "rm_trial.sh removes the trial" "$?$( [ -e "$L/trials/t2" ] && echo LEFT)" "0"
chk "  ...and prunes its worktree" "$(git -C "$L/app" worktree list | wc -l | tr -d ' ')" "1"
# realpath: node resolves symlinks in __dirname, and macOS $TMPDIR is under /var -> /private/var.
cfg="$(node -e 'const c=require(process.argv[1]); console.log(c.testDir===require("fs").realpathSync(require("path").dirname(process.argv[1])), !!(c.use.launchOptions))' "$PWD/$E/spec/playwright.config.js")"
chk "playwright.config: testDir = own dir, no forced browser" "$cfg" "true false"
cfg="$(PW_CHROMIUM_PATH=/x/chrome node -e 'console.log(require(process.argv[1]).use.launchOptions.executablePath)' "$PWD/$E/spec/playwright.config.js")"
chk "  ...PW_CHROMIUM_PATH honoured when set" "$cfg" "/x/chrome"

echo "== dispatch.sh: a worktree per ticket, never checkout -B"
git checkout -q -b my-feature-branch
cat > "$WORK/shims/opencode" <<'OC'
#!/bin/sh
echo "round by stub" >> ROUNDS; git add ROUNDS; git commit -q -m "ticket-0007: stub round"
[ -n "$STUB_STASH" ] && { echo x >> README.md; git stash -q; }
exit "${STUB_RC:-0}"
OC
chmod +x "$WORK/shims/opencode"
export OPENAI_BASE_URL=http://stub OPENAI_API_KEY=stub RELAY_MODEL=stub
DP="$WORK/shims:$PATH"
out="$(PATH="$DP" "$B" scripts/dispatch.sh 0007 --dry-run 2>&1)"; has "--dry-run names the worktree" "$out" "would use worktree:"
PATH="$DP" "$B" scripts/dispatch.sh 0007 >/dev/null 2>&1; chk "round 1 succeeds" "$?" "0"
chk "your checkout is NOT switched (was: checkout -B)" "$(git rev-parse --abbrev-ref HEAD)" "my-feature-branch"
chk "worktree created" "$( [ -d .worktrees/ticket-0007 ] && echo yes)" "yes"
c1="$(git rev-list --count ticket/0007)"
git checkout -q my-feature-branch   # back to your own work between rounds
PATH="$DP" "$B" scripts/dispatch.sh 0007 >/dev/null 2>&1
chk "round 2 keeps round 1's commit (was: reset by checkout -B)" "$(git rev-list --count ticket/0007)" "$((c1+1))"
out="$(cd .worktrees/ticket-0007 && PATH="$DP" "$B" scripts/dispatch.sh 0007 --dry-run 2>&1)"
hasnt "run from inside the worktree -> no nesting" "$out" ".worktrees/ticket-0007/.worktrees"
chk ".worktrees ignored in your status" "$(git status --porcelain | grep -c worktrees)" "0"
out="$(STUB_STASH=1 PATH="$DP" "$B" scripts/dispatch.sh 0007 2>&1)"; has "stash changed during a round -> WARNING" "$out" "the stash changed during this round"
STUB_RC=4 PATH="$DP" "$B" scripts/dispatch.sh 0007 >/dev/null 2>&1; chk "the implementer's exit code propagates" "$?" "4"
finish
