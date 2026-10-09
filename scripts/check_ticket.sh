#!/usr/bin/env bash
# check_ticket.sh <ticket.md> — mechanical pre-flight. No model, no judgement.
#
# Refuses to pass a ticket that is not dispatchable. Every check here exists
# because its absence cost a round (or nine trials) in runs 02-04.
set -uo pipefail
cd "$(dirname "$0")/.."
T="${1:?usage: check_ticket.sh tickets/NNNN-name.md}"
[ -f "$T" ] || { echo "FAIL: no such ticket: $T"; exit 1; }

fails=0
ok()   { printf '  ok    %s\n' "$1"; }
bad()  { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

echo "== ticket pre-flight: $T =="

# 1. Required sections, non-empty (a heading with nothing under it is not a spec).
for sec in "## Goal" "## Structure and dependencies" "## Invariants" "## Non-goals" \
           "## Specification" "## Acceptance" "## How to run the tests" \
           "## If the contract is broken"; do
  if ! grep -qF "$sec" "$T"; then
    bad "missing section: $sec"
  else
    body=$(awk -v s="$sec" 'index($0,s)==1{f=1;next} /^## /{f=0} f' "$T" | tr -d '[:space:]')
    [ -n "$body" ] && ok "$sec" || bad "empty section: $sec"
  fi
done

# 2. Header fields.
for f in "**Status**" "**Scope (writable paths)**" "**Acceptance command**" "**Dispatch budget**"; do
  grep -qF "$f" "$T" && ok "header: $f" || bad "missing header field: $f"
done

# 3. Placeholders left in from the template.
if grep -qE '<[A-Z]?[a-z][^>]{10,}>' "$T"; then
  bad "unfilled template placeholders remain (<...>)"
else
  ok "no template placeholders"
fi

# 4. The tests the ticket names must EXIST and be COLLECTED.
#    Run 04 lost nine trials to a probe whose tests were never on the branch.
#    Portable to bash 3.2 (macOS /bin/bash): no mapfile, and no array, because
#    expanding an empty array under `set -u` is an error before bash 4.4. Under
#    3.2 the old mapfile line failed and this whole check was SILENTLY SKIPPED.
named=$(grep -oE '[A-Za-z0-9_/]+test_[A-Za-z0-9_]+\.py' "$T" | sort -u)
if [ -z "$named" ]; then
  ok "no test files named in ticket (nothing to verify)"
else
  # Read from fd 3, not stdin: pytest and find run inside this loop, and any
  # command that reads stdin would silently eat the rest of the list.
  while IFS= read -r t <&3; do
    path=$(find parser -name "$(basename "$t")" -print -quit 2>/dev/null)
    if [ -z "$path" ]; then
      bad "ticket names $t but no such file exists in the tree"
    elif PYTHONPATH="$PWD/parser/src" python3 -m pytest --collect-only -q "$path" >/dev/null 2>&1; then
      ok "test file present and collectable: $path"
    else
      bad "$path exists but pytest cannot collect it"
    fi
  done 3<<EOF
$named
EOF
fi

# 5. Gates must currently be RED. A ticket whose gates are already green is
#    either finished or its acceptance tests are not wired into the suite.
#    Branch on the exit code, not on success/failure: gates.sh exits 3 (BROKEN)
#    when its tooling cannot run, and a gate that never ran is not a red gate.
#    The old `if gates.sh` read BROKEN as RED and passed the ticket.
scripts/gates.sh >/dev/null 2>&1
rc=$?
case "$rc" in
  0) bad "gates are already GREEN — this ticket has no red surface to earn" ;;
  1) ok  "gates are RED (there is work to do)" ;;
  3) bad "gates are BROKEN — the tooling cannot run, so RED cannot be established (run scripts/gates.sh to see why)" ;;
  *) bad "gates exited $rc — neither GREEN, RED nor BROKEN; investigate before dispatching" ;;
esac

echo
if [ "$fails" -eq 0 ]; then
  echo "PRE-FLIGHT: PASS — dispatchable"
  exit 0
fi
echo "PRE-FLIGHT: $fails problem(s) — fix the ticket before dispatching"
exit 1
