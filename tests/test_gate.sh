#!/usr/bin/env bash
# test_gate.sh — the run-07 gate's verdicts, with php, the server, curl and
# Playwright stubbed out. What matters is that the gate never reports a score it
# did not measure (instrument bugs 9, 10 and the rest of that class): anything
# short of six specs that each reached a verdict must be NORESULT, never 0/6.
. "$(dirname "$0")/lib.sh"
need python3
E="$REPO/experiments/statamic-blueprint-revisions"; B="$BASH_UT"

L="$WORK/lab"; mkdir -p "$L/spec" "$L/harness" "$L/app/database"
echo db > "$L/spec/pristine.sqlite"

# Stubs. php: tinker seeds print SEEDED, check_contents prints $STUB_AFTER, and
# serve idles until killed. curl: exits $STUB_UP. npx: copies $STUB_RESULT to
# the gate's result file (if set) and exits $STUB_PW_RC. sleep and pkill: no-ops.
S="$WORK/stubs"; mkdir -p "$S"
REAL_SLEEP="$(command -v sleep)"
cat > "$S/php" <<EOF
#!/bin/sh
case "\$*" in
  *seed_edits*)     echo SEEDED ;;
  *check_contents*) echo "\${STUB_AFTER:-Body}" ;;
  *" serve "*)      exec "$REAL_SLEEP" 30 ;;
esac
exit 0
EOF
printf '#!/bin/sh\nexit "${STUB_UP:-0}"\n' > "$S/curl"
printf '#!/bin/sh\n[ -n "${STUB_RESULT:-}" ] && cp "$STUB_RESULT" "$GATE_RESULT"\nexit "${STUB_PW_RC:-0}"\n' > "$S/npx"
printf '#!/bin/sh\nexit 0\n' > "$S/sleep"; printf '#!/bin/sh\nexit 0\n' > "$S/pkill"
chmod +x "$S"/*

# result <file> <status>... — a Playwright JSON report, one spec per status.
result() {
  f="$1"; shift
  python3 - "$f" "$@" <<'PY'
import json, sys
specs = [{"title": f"t{i}", "tests": ([] if s == "none" else [{"status": s}])} for i, s in enumerate(sys.argv[2:])]
json.dump({"suites": [{"specs": specs}]}, open(sys.argv[1], "w"))
PY
}
gate() { out="$(env PATH="$S:$PATH" LAB_ROOT="$L" GATE_AUDIT_LOG="$WORK/audit.log" "$B" "$E/spec/gate.sh" "$L/app" 59917 2>&1)"; rc=$?; }
R="$WORK/r.json"; x=expected; u=unexpected

echo "== verdicts the gate measured"
result "$R" $x $x $x $x $x $x; STUB_RESULT="$R" gate
chk "6 expected -> GREEN (0)" "$rc" "0"; has "  ...scores 6/6" "$out" "SCORE: 6/6"
result "$R" $x $x $x $x $u $u; STUB_RESULT="$R" STUB_PW_RC=1 gate
chk "4 expected, 2 failed -> RED (1)" "$rc" "1"; has "  ...scores 4/6" "$out" "SCORE: 4/6"
result "$R" $u $u $u $u $u $u; STUB_RESULT="$R" STUB_PW_RC=1 gate
chk "all six failed -> a measured 0/6 is still RED" "$rc" "1"; has "  ...scores 0/6" "$out" "SCORE: 0/6"
result "$R" $x $x $x $x $x $x; STUB_RESULT="$R" STUB_AFTER=Changed gate
chk "Playwright green but restore didn't revert -> RED" "$rc" "1"

echo "== no measurement -> NORESULT (3), never a score"
rm -f "$R"; STUB_PW_RC=1 gate
chk "no result file (bug 10: was 0/6) -> 3" "$rc" "3"; has "  ...says NORESULT" "$out" "GATE: NORESULT"
hasnt "  ...and prints no numeric score" "$out" "SCORE: 0/6"
echo 'not json' > "$R"; STUB_RESULT="$R" STUB_PW_RC=1 gate
chk "unreadable result file -> 3" "$rc" "3"
result "$R"; STUB_RESULT="$R" STUB_PW_RC=1 gate
chk "zero specs -> 3" "$rc" "3"
result "$R" $x $x $x $x $x; STUB_RESULT="$R" gate
chk "five specs, not six -> 3" "$rc" "3"
result "$R" $x $x $x skipped skipped skipped; STUB_RESULT="$R" STUB_PW_RC=1 gate
chk "specs that never ran (skipped) -> 3, not a 3/6" "$rc" "3"
result "$R" $x $x interrupted $u $u $u; STUB_RESULT="$R" STUB_PW_RC=1 gate
chk "an interrupted spec -> 3" "$rc" "3"
result "$R" $x $x $x $x $x none; STUB_RESULT="$R" gate
chk "a spec with no tests -> 3" "$rc" "3"
result "$R" $x $x $x $x $x $x; STUB_RESULT="$R" STUB_UP=1 gate
chk "server never answered -> 3, even with a stale green report" "$rc" "3"; has "  ...says why" "$out" "server did not answer"

chk "every run went to GATE_AUDIT_LOG, not /tmp" "$(wc -l < "$WORK/audit.log" | tr -d " ")" "12"

finish
