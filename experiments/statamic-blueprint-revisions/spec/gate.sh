#!/usr/bin/env bash
# gate.sh <app-dir> <port> — black-box acceptance gate. Exit 0 = GREEN.
set -uo pipefail
APP="${1:-${LAB_ROOT:-}/app}"; PORT="${2:-8000}"
S="${LAB_ROOT:-}/spec"

# Audit EVERY invocation, including a trial running the gate on itself. Arm A's
# premise is "no checker available" — but gate.sh is world-readable two levels
# up from a trial's worktree (../../spec/gate.sh), and in run 07 trials found it and ran it. This file
# is the only thing that distinguishes a blind arm from a confounded one. Without
# it the confound is invisible and the arm's result reads as a capability finding.
echo "$(date +%s) $APP $$" >> /tmp/gate-audit.log

# The lab lives under LAB_ROOT (README: "Rebuilding the lab"). Unset is BROKEN,
# exit 3 — not RED, exit 1. A missing setting must never be able to score a trial.
[ -n "${LAB_ROOT:-}" ] || { echo "GATE: BROKEN — LAB_ROOT is not set"; exit 3; }

cd "$APP" || { echo "GATE: BROKEN — no app dir"; exit 3; }

# hermetic start: restore the pristine DB so revision history never accumulates
# across gate runs (blueprints + CP user live in this file).
cp "$S/pristine.sqlite" "$APP/database/database.sqlite" || { echo "GATE: BROKEN — no pristine db"; exit 3; }

php artisan migrate --force >/dev/null 2>&1
php artisan optimize:clear >/dev/null 2>&1

# reset fixture to a known state, then make two edits
php artisan tinker --execute="require '$S/reset_fixture.php';" >/dev/null 2>&1
sleep 2   # keep the reset save in its own second so revision ordering is unambiguous
SEED=$(php artisan tinker --execute="require '$S/seed_edits.php';" 2>&1 | grep SEEDED)
[ -z "$SEED" ] && { echo "GATE: BROKEN — fixture seed failed"; exit 3; }

# multiple workers: the single-process built-in server deadlocks when a test
# issues a request while the page it just opened still has one in flight.
PHP_CLI_SERVER_WORKERS=8 php artisan serve --host=127.0.0.1 --port="$PORT" >/tmp/gate-serve-$PORT.log 2>&1 &
SRV=$!
for i in $(seq 1 20); do sleep 1; curl -sS -o /dev/null -m 5 "http://127.0.0.1:$PORT/cp/auth/login" 2>/dev/null && break; done

rm -f "/tmp/gate-storage-state-$PORT.json"
RESULT="/tmp/gate-result-$PORT.json"; rm -f "$RESULT"
BASE_URL="http://127.0.0.1:$PORT" GATE_STATE="/tmp/gate-storage-state-$PORT.json" \
  GATE_RESULT="$RESULT" GATE_OUTPUT="/tmp/gate-artifacts-$PORT" \
  npx --prefix "$LAB_ROOT/harness" playwright test \
  --config "$S/playwright.config.js" 2>&1 | tail -30
RC=${PIPESTATUS[0]}
SCORE=$(python3 -c "
import json,sys
try:
    d=json.load(open('$RESULT'))
except Exception: print('0/6'); sys.exit()
ok=tot=0
def passed(sp):
    tests = sp.get('tests') or []
    if not tests: return False
    # a test that never ran reports 'skipped' — it is not a pass.
    return all(t.get('status') == 'expected' for t in tests)
def walk(s):
    global ok,tot
    for sp in s.get('suites',[]): walk(sp)
    for sp in s.get('specs',[]):
        tot+=1
        if passed(sp): ok+=1
for s in d.get('suites',[]): walk(s)
print(f'{ok}/{tot if tot else 6}')
" 2>/dev/null)
echo "SCORE: $SCORE"

# independent post-check: did restore actually change stored contents?
AFTER=$(php artisan tinker --execute="require '$S/check_contents.php';" 2>&1 | tail -1 | tr -d '\r')
kill "$SRV" 2>/dev/null; wait "$SRV" 2>/dev/null
# artisan serve spawns a `php -S` child that SURVIVES killing the wrapper and
# goes on holding the port, so the next run on this port refuses to start and
# scores NORESULT. Cost one trial (s050) before it was diagnosed. The trailing
# space in the pattern is load-bearing: without it, port 850 also kills 8500.
pkill -f "php.*-S 127.0.0.1:$PORT " 2>/dev/null

echo "post-restore body display = $AFTER"
if [ "$RC" -eq 0 ] && [ "$AFTER" = "Body" ]; then echo "GATE: GREEN"; exit 0; fi
[ "$RC" -eq 0 ] && echo "  (playwright passed but restore did not revert contents to 'Body')"
echo "GATE: RED"; exit 1
