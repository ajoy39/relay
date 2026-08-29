#!/usr/bin/env bash
# review.sh — the frontier pass over the implementer's diff.
#
#   scripts/review.sh main          # review current branch against main
#
# Uses `claude -p` (headless), which draws from the plan's monthly agent credit.
# That credit exhausts with NO automatic fallback — so this script degrades to a
# queue instead of blocking or silently passing: an unreviewable diff waits in
# review-queue.md for an interactive review. Constraints are fine as long as
# they're never silent.
set -euo pipefail
cd "$(dirname "$0")/.."

BASE="${1:?usage: review.sh <base-ref>}"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
DIFF="$(git diff "${BASE}...HEAD")"
[ -n "$DIFF" ] || { echo "no diff against ${BASE} — nothing to review"; exit 0; }

OUT="reviews/$(date +%Y%m%d-%H%M%S)-${BRANCH//\//-}.md"
mkdir -p reviews

queue() {
  {
    echo "- $(date -u +%FT%TZ) — \`${BRANCH}\` vs \`${BASE}\` — headless review unavailable ($1)."
    echo "  Review interactively, then remove this line."
  } >> review-queue.md
  echo "review DEGRADED -> queued in review-queue.md (${1})"
  echo "NOT approved. Do not merge until a review exists."
}

if ! command -v claude >/dev/null 2>&1; then
  queue "claude CLI not installed"
  exit 0
fi

PROMPT="You are the architect reviewing an implementer's diff. Gates are already green,
so do not re-verify behavior — judge what tests cannot, per docs/protocol.md's review
checklist: unrequested changes, structure, untested load-bearing code, silent error
paths, readability. The ticket is in tickets/. End with exactly one verdict line:
VERDICT: approve | VERDICT: request-changes | VERDICT: escalate — followed by numbered,
actionable notes."

if echo "$DIFF" | claude -p "$PROMPT" > "$OUT" 2>"$OUT.err"; then
  rm -f "$OUT.err"
  echo "review written: $OUT"
  grep -m1 "^VERDICT:" "$OUT" || echo "WARNING: no VERDICT line — treat as request-changes"
else
  queue "claude -p failed — likely agent credit exhausted; see $OUT.err"
  exit 0
fi
