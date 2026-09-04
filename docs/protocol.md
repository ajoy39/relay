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

## Amendment (run 04): stop-and-report is documentation, not a mechanism

The lifecycle diagram above shows a **stop-and-report** path — the implementer
detecting that the spec contradicts itself and escalating to the architect
instead of bulldozing. In 20+ observed rounds across three local models, that
path has fired **zero** times.

Run 04 tested it directly. A ticket was built whose tests are unsatisfiable by
construction (two tests demanding different item counts from one fixture). Six
trials under the standard rules: zero reports, five explicit claims of success.
Three further trials whose prompt opened with "before writing any code, verify
the tests are mutually satisfiable; if they are not, STOP and name the conflict":
zero reports. One of those trials wrote "let me verify they are satisfiable" and
then implemented anyway. Instruction-following at the surface, not the semantic
level.

Treat the rule accordingly:

- **Keep rule 4 in dispatch prompts.** It costs nothing and may bind on a
  stronger model.
- **Do not build on it.** Any part of the workflow that assumes the implementer
  will surface a bad spec is unprotected. What actually protects the work is the
  part with no model in it: the gates, the round budget, and an architect who
  reads the diff.
- **Corollary for the architect:** a contradictory spec will not come back as a
  question. It comes back as a confident success report over red gates. Verify
  ticket arithmetic and test consistency *before* dispatch — a one-cent fixture
  error in run 02 cost a 100-minute round for exactly this reason.
