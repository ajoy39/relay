# relay

Frontier architect, local implementer. A working demonstration of delegating implementation to a
self-hosted model through written specs, with verification gates deciding what merges and a
frontier model reviewing what the gates can't judge.

The bet this repo exists to test: **wall-clock time converts to reliability.** A local open model
with a 10× time budget — retries, tests-as-oracle, review loops — can land a large share of what a
frontier model lands in one attempt, for work that is *well-specified and verifiable*. The pattern
concentrates the frontier model where its edge actually is (judgment, specs, review) and the local
model where the tokens are (implementation), and the seam between them is a written artifact you
can read, diff, and improve.

## The division of labor

| Role | Who | Spends |
|---|---|---|
| **Architect** | Frontier model (Claude), interactive | Subscription — spec-writing is cheap, judgment-dense |
| **Implementer** | Local model on the N5 (llama.cpp endpoint) | Electricity and patience |
| **Gates** | pytest + lint, no model at all | Nothing. The gates are the only party that can't be argued with |
| **Reviewer** | Frontier model, headless (`claude -p`) or interactive | Agent credit — a diff review is a fraction of an implementation session |

The flow, per ticket: the architect writes a spec with acceptance tests → `scripts/dispatch.sh`
hands it to the local implementer on a branch → `scripts/gates.sh` runs until green →
`scripts/review.sh` gets the frontier pass → merge. Full lifecycle in
[`docs/protocol.md`](docs/protocol.md).

## What you give up (recorded honestly, so the first bad week doesn't read as failure)

1. **Implementation-time design discovery.** A frontier model mid-implementation notices the
   design is wrong and renegotiates; a local model satisfies the letter of the spec. Mitigation:
   specs carry invariants, non-goals, and *stop-and-report conditions* — see the
   [ticket template](tickets/TEMPLATE.md).
2. **Taste in the small.** Naming, idiom, when-to-refactor. The review pass is where taste
   re-enters; expect to spend it there.
3. **The weird debugging tail.** Some tasks will burn the whole time budget circling. The
   escalation rule exists for exactly this: **a ticket that fails its gates after N dispatch
   rounds (default 3) comes back to the architect** — that's the system working, not failing.
4. **Completion rate without supervision**, early on. It improves with the models and with spec
   quality, and spec quality is the part you control.

## Economics (as of late 2026 — verify before trusting, billing rots fast)

Interactive frontier work (specs, reviews you drive by hand) is subscription usage. Headless
frontier work (`claude -p` in `review.sh`, Agent SDK) draws from the plan's **monthly agent
credit** at API rates — no rollover, and **no automatic fallback** when exhausted. `review.sh`
therefore degrades to a queue (`review-queue.md`) instead of blocking: an unreviewable diff waits
for interactive review; it never silently merges and never wedges the pipeline. Constraints are
fine as long as they're never silent.

The implementation tokens — the bulk of any agentic session — cost nothing but watts, which is
the entire point.

## Layout

```
docs/protocol.md        the ticket lifecycle and the rules that make it safe
docs/setup-n5.md        serving a model from the N5 Pro (TrueNAS + llama.cpp), tunnel, auth
docs/setup-harness.md   opencode against the local endpoint; alternatives
tickets/                specs; TEMPLATE.md is the contract format
scripts/                dispatch, gates, review — the loop, in ~200 lines of shell total
parser/                 ticket 0001's workspace: acceptance tests (red until the
                        implementer earns green) and an empty src/
```

## Status

Ticket [`0001`](tickets/0001-receipt-parser.md) is **open** and its gates are **red by design** —
red gates are what "ready for the implementer" looks like. The parser in `parser/src/` will be
written by the local model, not by the architect who wrote this README. That asymmetry is the
demonstration.

## Boundaries

- The endpoint URL and credentials are runtime configuration (`OPENAI_BASE_URL`,
  `OPENAI_API_KEY`). They never appear in this repo.
- Steady state is LAN/Tailscale-only serving. The Cloudflare tunnel is opt-in remote access and
  routes prompts through a third party — acceptable deliberately, never accidentally.
- Delegation, not distillation: frontier outputs (specs, reviews) direct the local model's work;
  they are not harvested as training data. The line comes from the provider's terms and it's a
  sensible line regardless.
