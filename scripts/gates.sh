#!/usr/bin/env bash
# gates.sh — the merge precondition. No model involved; this is the party that
# can't be argued with. Exit 0 = green.
set -euo pipefail
cd "$(dirname "$0")/.."

export PYTHONPATH="$PWD/parser/src${PYTHONPATH:+:$PYTHONPATH}"

status=0

if ! python3 -m pytest --version >/dev/null 2>&1; then
  echo "GATES: BROKEN — pytest is not installed (pip install pytest)." >&2
  echo "A gate that can't run is not a red gate; fix the tooling first." >&2
  exit 3
fi

echo "== gate: pytest =="
if ! python3 -m pytest parser/tests -q; then
  status=1
fi

# Lint is advisory-strict: runs when available, required when present.
if command -v ruff >/dev/null 2>&1; then
  echo "== gate: ruff =="
  if ! ruff check parser/src; then
    status=1
  fi
else
  echo "== gate: ruff not installed — skipped (install for the full gate) =="
fi

if [ "$status" -eq 0 ]; then
  echo "GATES: GREEN"
else
  echo "GATES: RED"
fi
exit "$status"
