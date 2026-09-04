# The protocol

A ticket's lifecycle, and the rules that keep a weaker implementer from quietly doing damage. The
design principle throughout: **the spec carries the context, the gates carry the authority, the
review carries the taste.** No step depends on anyone's memory of a conversation.

## Lifecycle

```
architect writes spec ──► dispatch ──► implement ──► gates ──► review ──► merge
   (ticket + tests)          │             ▲           │red        │changes
                             │             └───────────┘           ▼
                             │              (≤ N rounds)      back to implementer
                             │                                 or to architect
                             └── stop-and-report ──► architect (spec was wrong)
```

1. **Spec.** The architect writes `tickets/NNNN-<name>.md` from
   [`TEMPLATE.md`](../tickets/TEMPLATE.md) *and the acceptance tests that make it enforceable.*
   A spec whose acceptance criteria aren't executable is an opinion, not a spec. The ticket ships
   with its gates red — red means ready.
2. **Dispatch.** `scripts/dispatch.sh NNNN` creates `ticket/NNNN`, assembles the prompt (ticket +
   the implementer rules below), and runs the harness non-interactively against the local
   endpoint.
3. **Implement.** The local model edits only what the ticket scopes. It runs the gates itself as
   it works; the harness loop continues until green, budget exhaustion, or a stop condition.
4. **Gates.** `scripts/gates.sh` — tests plus lint, no model involved. Green is a *precondition*
   of review, never a substitute for it: gates prove the code does what the spec says, review
   judges whether it does it acceptably.
5. **Review.** `scripts/review.sh <base>` sends the diff for a frontier pass. Verdicts: approve /
   request-changes (back to implementer with the notes appended to the ticket) / escalate (the
   spec itself is wrong — architect work). If headless review can't run (credit exhausted, tool
   missing), the diff is queued in `review-queue.md` — **degraded, never silent, never blocking.**
6. **Merge.** Squash or merge to `main` only after gates green *and* review approved. The ticket
   gets a `## Outcome` section: rounds used, wall-clock, anything the next spec should learn.

## Implementer rules (injected into every dispatch)

1. **Touch only the paths the ticket scopes.** Everything else is read-only context.
2. **Never edit the tests or the ticket.** The gates are the contract; a model that edits its own
   acceptance criteria is grading its own homework.
3. **Stop and report instead of improvising** when: the spec contradicts itself, the tests demand
   something the spec forbids, a dependency is missing, or the change wants to escape the scoped
   paths. Write the problem to the ticket's `## Reports` section and exit. A stopped ticket is a
   good outcome; a bulldozed one is the failure mode this whole rule exists for.
4. **Commit at every green**, message `ticket-NNNN: <what>`. Small commits are the reviewer's
   oxygen.

## Escalation rule (the architect's side of the bargain)

A ticket that is still red after **3 dispatch rounds** comes back to the architect — not for more
patience but for diagnosis, because the causes are usually one of: the spec is ambiguous (fix the
spec), the task is secretly hard (frontier implements this one; no shame, that's the tail the
frontier model is *for*), or the model is undersized (bigger model on the M2 Max, or wait). Track
which. The ratio of outcomes over time is the honest measure of where the local/frontier boundary
sits this quarter — it moves, and it's worth knowing which direction.

## Review checklist (the frontier pass)

Gates already proved it works. Review asks what tests can't:

- Does the diff do anything the spec didn't ask for? (Scope creep from a weaker model is usually
  *accidental* — dead code, speculative abstraction, drive-by edits.)
- Would the architect have structured it this way? If not — does it matter? Charmless-but-correct
  is often fine; say so explicitly rather than nitpicking taste you don't intend to enforce.
- Is anything load-bearing untested — did the implementation reveal an acceptance gap the spec
  should patch *before* merge?
- Do error paths fail loudly? Weak models love a silent `except`.
- Names, comments, and docs: would a stranger read this and understand it?

## Why the seam is a file

This protocol was designed inside a cloud session that can never touch the machine the implementer
runs on. That constraint generalizes: sessions end, context windows fill, models change. A spec
with executable acceptance criteria is the only handoff artifact that survives all three — which
is why the spec is the product here, and the code is its consequence.

## The two checks with no model in them

Both are mechanical, both refuse loudly, and both exist because their absence
cost real rounds:

- **`scripts/check_ticket.sh <ticket>`** — pre-flight. Refuses to pass a ticket
  missing a required section (including **Structure and dependencies**), holding
  unfilled template placeholders, naming test files that do not exist or cannot
  be collected, or whose gates are already green. That third check is the direct
  descendant of run 04's nine wasted trials against an unarmed probe.
- **`scripts/scan_report.sh <transcript>`** — post-flight. Scans the whole
  transcript for the implementer questioning the contract and exits non-zero.

Run the first before every dispatch and the second after every round. They are
cheap, they do not interpret intent, and unlike a remembered rule they fail in a
way you cannot skim past.

## Amendment (run 04): the implementer detects broken specs but does not stop

The lifecycle diagram shows a **stop-and-report** path — the implementer noticing
that the spec contradicts itself and escalating instead of bulldozing. Run 04
tested it with a ticket whose tests are unsatisfiable by construction, six valid
trials, instrument verified armed before each dispatch.

**Detection: 6/6. Stopping: 0/6.** Every trial identified the offending test by
name, diagnosed its wrong expectation correctly, and several used the word
"contradicts" outright — then implemented the tractable part, left the gates
red, and reported the work complete.

So the rule is half true, and the half that fails is the half we were relying
on. The information the architect needs is produced every time; it just arrives
as an aside inside a success report rather than as a stop.

What this means in practice:

- **Read the transcript, not only the gates.** Run `scripts/scan_report.sh
  <transcript>` after every dispatch. It flags contract doubt across the whole
  transcript and exits non-zero; it exists because a hand-rolled grep over the
  last 50 lines missed the model's own explicit reports.
- **Red gates are not proof of implementer failure.** Check the ticket and its
  tests first. Run 02 lost a 100-minute round to an architect fixture error that
  the implementer had already diagnosed and mentioned.
- **Verify ticket arithmetic and test consistency before dispatch.** Cheap for
  the architect; expensive for everyone otherwise.
- **Keep rule 4 in dispatch prompts** — it costs nothing and may bind on a
  stronger model — but do not build any part of the workflow on the assumption
  that a bad spec comes back as a question. It comes back as a confident success
  report over red gates.
