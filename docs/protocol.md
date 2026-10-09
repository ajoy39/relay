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

## The check with no model in it

It is mechanical, it refuses loudly, and it exists because its absence
cost real rounds:

- **`scripts/check_ticket.sh <ticket>`** — pre-flight. Refuses to pass a ticket
  missing a required section (including **Structure and dependencies**), holding
  unfilled template placeholders, naming test files that do not exist or cannot
  be collected, or whose gates are already green. That third check is the direct
  descendant of run 04's nine wasted trials against an unarmed probe.
Run it before every dispatch. It is cheap, it does not interpret intent, and
unlike a remembered rule it fails in a way you cannot skim past.

A post-flight transcript scanner was specified here after run 04 and never
built; the requirement was dropped on 2026-10-09. What it targeted — a contract
objection buried as an aside inside a success report — is now caught only by
**reading the whole transcript** after every round.

## Amendment (runs 04–05): stop-and-report works above a capability floor

The lifecycle diagram shows a **stop-and-report** path — the implementer noticing
that the spec contradicts itself and escalating instead of bulldozing. Two runs
tested it with a ticket whose tests are unsatisfiable by construction, with the
instrument verified armed before every dispatch.

| Implementer | Detected the contradiction | Stopped |
|---|---|---|
| qwen3-coder-30b (local) | 6/6 | **0/6** |
| Claude Haiku 4.5 | 3/3 | **3/3** |

An earlier version of this amendment concluded from the 30B alone that the path
"is documentation, not a mechanism." That was wrong — it was a claim about one
implementer stated as a claim about the protocol. Haiku stopped every time, once
in 16 seconds and 3 tool calls, naming both conflicting tests and writing no
code.

The difference is not perception. The 30B identified the offending test and
diagnosed its wrong expectation correctly every single time — and implemented
anyway, reporting success over red gates. Detecting a broken contract and
treating that as a reason to stop are separate capabilities, and the second one
resisted four escalating styles of feedback.

**What this means in practice:**

- **Know which side of the floor your implementer is on**, and configure
  accordingly. Above it, the escalation path is real and you can act on reports.
  Below it, it does not exist and nothing should be built on it.
- **Below the floor, read the transcript, not only the gates** — after every
  dispatch. The 30B's reports are accurate, they just arrive as an aside inside
  a false success claim.
- **Red gates are not proof of implementer failure.** Check the ticket and its
  tests first. Run 02 lost a 100-minute round to an architect fixture error the
  implementer had already diagnosed.
- **Verify ticket arithmetic and test consistency before dispatch** —
  `scripts/check_ticket.sh` does the mechanical half. Cheap for the architect,
  expensive for everyone otherwise.
