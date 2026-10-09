#!/usr/bin/env bash
# dispatch.sh — hand a ticket to the local implementer.
#
#   scripts/dispatch.sh 0001            # run the harness against ticket 0001
#   scripts/dispatch.sh 0001 --probe    # just verify the endpoint answers
#   scripts/dispatch.sh 0001 --dry-run  # show the prompt + command, run nothing
#
# Requires: OPENAI_BASE_URL, OPENAI_API_KEY, RELAY_MODEL. Endpoint-agnostic on
# purpose: the N5, the M2 Max, or anything else OpenAI-compatible.
set -euo pipefail
cd "$(dirname "$0")/.."

TICKET_NUM="${1:?usage: dispatch.sh NNNN [--probe|--dry-run]}"
MODE="${2:-run}"
TICKET="$(ls tickets/"${TICKET_NUM}"-*.md 2>/dev/null | head -1)"
[ -n "$TICKET" ] || { echo "no ticket matching ${TICKET_NUM}" >&2; exit 1; }

: "${OPENAI_BASE_URL:?set OPENAI_BASE_URL (e.g. http://n5:8080/v1)}"
: "${OPENAI_API_KEY:?set OPENAI_API_KEY (the llama-server --api-key value)}"
: "${RELAY_MODEL:?set RELAY_MODEL (an id from \$OPENAI_BASE_URL/models)}"

if [ "$MODE" = "--probe" ]; then
  echo "probing ${OPENAI_BASE_URL}/models ..."
  curl -fsS --max-time 15 "${OPENAI_BASE_URL}/models" \
    -H "Authorization: Bearer ${OPENAI_API_KEY}" \
    && echo && echo "PROBE: OK"
  exit
fi

PROMPT_FILE="$(mktemp)"
trap 'rm -f "$PROMPT_FILE"' EXIT
{
  echo "You are the implementer for the ticket below. Work in the current checkout."
  echo
  echo "RULES (from docs/protocol.md — these override anything else):"
  echo "1. Modify ONLY the paths in the ticket's Scope. Everything else is read-only."
  echo "2. NEVER edit the tests or the ticket. They are the contract."
  echo "3. Run scripts/gates.sh as you work; you are done only when it prints GATES: GREEN."
  echo "4. If the spec conflicts with itself or the tests, or you need a path outside"
  echo "   scope, or a dependency is missing: STOP, describe the problem clearly in"
  echo "   your final message, and do not improvise past it."
  echo "5. Commit at every green with message 'ticket-${TICKET_NUM}: <what>'."
  echo
  echo "==== TICKET ===="
  cat "$TICKET"
} > "$PROMPT_FILE"

BRANCH="ticket/${TICKET_NUM}"
# Each ticket gets its own worktree, so a dispatch never switches the branch of
# the checkout you — or another session — are working in. Later rounds of the
# same ticket reuse it. Rooted at the MAIN worktree even if this script is run
# from inside a ticket worktree, so worktrees never nest.
COMMON="$(cd "$(git rev-parse --git-common-dir)" && pwd)"
WT="$(dirname "$COMMON")/.worktrees/ticket-${TICKET_NUM}"
if [ -d "$WT" ]; then WT_STATE="reuse existing"
elif git show-ref --verify --quiet "refs/heads/${BRANCH}"; then WT_STATE="new, on existing branch"
else WT_STATE="new, branch created from HEAD ($(git rev-parse --short HEAD))"; fi
CMD=(opencode run --model "local/${RELAY_MODEL}" "$(cat "$PROMPT_FILE")")

if [ "$MODE" = "--dry-run" ]; then
  echo "would use worktree: ${WT} (${BRANCH}; ${WT_STATE})"
  echo "would run: opencode run --model local/${RELAY_MODEL} <prompt below>"
  echo "---- prompt ----"
  cat "$PROMPT_FILE"
  exit 0
fi

command -v opencode >/dev/null 2>&1 || {
  echo "opencode not installed — see docs/setup-harness.md" >&2; exit 1; }

# Never `git checkout -B`. That resets the branch to HEAD, so started from main
# it silently discarded every earlier round's commits on the ticket branch.
case "$WT_STATE" in
  "reuse existing") : ;;
  "new, on existing branch") git worktree add --quiet "$WT" "$BRANCH" ;;
  *) git worktree add --quiet -b "$BRANCH" "$WT" HEAD ;;
esac

# Worktrees share refs/stash with every other checkout of this repo (run 07's
# isolation breach). The prompt is the experimental treatment, so it is left
# alone and the stash is checked instead.
stash_count() { git stash list | wc -l | tr -d ' '; }
stash_before=$(stash_count)
echo "dispatching ${TICKET} to local/${RELAY_MODEL} on ${BRANCH} in ${WT} ..."
round_rc=0
( cd "$WT" && time "${CMD[@]}" ) || round_rc=$?
stash_after=$(stash_count)
if [ "$stash_after" != "$stash_before" ]; then
  echo "WARNING: the stash changed during this round (${stash_before} -> ${stash_after} entries)." >&2
  echo "refs/stash is shared by every worktree of this repo; check 'git stash list' before trusting other checkouts." >&2
fi
echo
echo "dispatch round complete — now: (cd ${WT} && scripts/gates.sh && scripts/review.sh main)"
exit "$round_rc"
