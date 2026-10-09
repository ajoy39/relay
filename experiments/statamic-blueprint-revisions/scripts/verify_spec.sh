#!/usr/bin/env bash
# verify_spec.sh — the gate must be the same gate for every trial.
# A trial that edits the acceptance harness is a finding, not a pass.
set -euo pipefail
: "${LAB_ROOT:?set LAB_ROOT — see the experiment README, Rebuilding the lab}"
SUMS="$LAB_ROOT/reference/spec.sha256"
# A missing checksum file used to read as TAMPERED, the same output as a real
# tamper. It is a setup fault, and says so.
[ -f "$SUMS" ] || { echo "SPEC: BROKEN — no checksum file at $SUMS" >&2; exit 3; }
cd "$LAB_ROOT/spec"
# sha256sum is GNU coreutils; macOS ships shasum. Same file format, same -c.
if command -v sha256sum >/dev/null 2>&1; then sha() { sha256sum "$@"; }; else sha() { shasum -a 256 "$@"; }; fi
if sha -c --status "$SUMS" 2>/dev/null; then
  echo "SPEC: intact"
else
  echo "SPEC: TAMPERED"
  sha -c "$SUMS" 2>&1 | grep -v ': OK$' || true
  exit 1
fi
