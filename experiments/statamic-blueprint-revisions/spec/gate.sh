#!/usr/bin/env bash
# gate.sh <app-dir> <port> — black-box acceptance gate. Exit 0 = GREEN.
set -uo pipefail
APP="${1:-/home/user/lab/app}"; PORT="${2:-8000}"
S=/home/user/lab/spec
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
  npx --prefix /home/user/lab/harness playwright test \
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

echo "post-restore body display = $AFTER"
if [ "$RC" -eq 0 ] && [ "$AFTER" = "Body" ]; then echo "GATE: GREEN"; exit 0; fi
[ "$RC" -eq 0 ] && echo "  (playwright passed but restore did not revert contents to 'Body')"
echo "GATE: RED"; exit 1
