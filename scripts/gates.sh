#!/usr/bin/env bash
# gates.sh — the merge precondition. No model involved; this is the party that
# can't be argued with. Exit 0 = green.
set -euo pipefail
cd "$(dirname "$0")/.."

export PYTHONPATH="$PWD/parser/src${PYTHONPATH:+:$PYTHONPATH}"

status=0

# Exit codes: 0 GREEN, 1 RED, 3 BROKEN. BROKEN means the gate could not measure
# anything, and callers must not read it as RED (check_ticket.sh branches on it).
broken() { echo "GATES: BROKEN — $1" >&2; echo "A gate that can't run is not a red gate; fix the tooling first." >&2; exit 3; }

python3 -m pytest --version >/dev/null 2>&1 || broken "pytest is not installed (pip install pytest)."
# Lint used to be skipped with a one-line note when ruff was missing, so a gate
# could print GREEN without having linted. A gate that skips a check must not
# be able to pass; the superproject also registers `ruff check parser/src`.
command -v ruff >/dev/null 2>&1 || broken "ruff is not installed (pip install ruff)."

echo "== gate: pytest =="
python3 -m pytest parser/tests -q || {
  rc=$?
  # 1 = failures and 2 = interrupted/collection errors are the implementer's
  # problem: RED. 3 internal error, 4 usage error, 5 no tests collected mean the
  # suite never measured the code: BROKEN.
  case "$rc" in 1|2) status=1 ;; *) broken "pytest exited $rc (internal/usage error, or no tests collected)." ;; esac
}

echo "== gate: ruff =="
ruff check parser/src || {
  rc=$?
  case "$rc" in 1) status=1 ;; *) broken "ruff exited $rc (configuration or internal error)." ;; esac
}

if [ "$status" -eq 0 ]; then
  echo "GATES: GREEN"
else
  echo "GATES: RED"
fi
exit "$status"
