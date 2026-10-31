#!/usr/bin/env bash
# tests/run.sh — run every suite and summarise.
# Exit 1 if any suite FAILED, else 3 if any was BROKEN (could not run), else 0.
# NOT APPLICABLE (a suite for another platform) is reported and does not count.
cd "$(dirname "$0")" || exit 3
BASH_UT="${BASH_UT:-/bin/bash}"; export BASH_UT
echo "bash under test: $BASH_UT ($("$BASH_UT" -c 'echo $BASH_VERSION'))"
summary=""; any_fail=0; any_broken=0
for s in test_scripts test_gate test_isolation test_vendor_manifest test_linux_mount; do
  echo; echo "==================== $s"
  "$BASH_UT" "./$s.sh"; rc=$?
  case "$rc" in
    0) r=PASS ;; 3) r=BROKEN; any_broken=1 ;; 4) r="not applicable" ;; *) r=FAIL; any_fail=1 ;;
  esac
  summary="$summary$(printf '  %-22s %s' "$s" "$r")
"
done
echo; echo "==================== summary"; printf '%s' "$summary"
[ "$any_fail" = 1 ] && exit 1; [ "$any_broken" = 1 ] && exit 3; exit 0
