# First run — the honest record

Night of 2026-08-30/31. Architect: Claude (cloud session). Implementer: qwen3-coder-30b
(Qwen3-Coder-30B-A3B-Instruct, Q4_K_M, 18.5GB) via llama.cpp/Vulkan on the N5 Pro, reached
through a Cloudflare tunnel. Gates: pytest + ruff, no model. This file is the experiment's
lab notebook; nothing here is cleaned up to look better than it went.

## The box, measured

| Metric | Value |
|---|---|
| Prefill | ~282 tok/s (3.9K-token prompt, uncached) |
| Decode | ~15 tok/s |
| KV cache | working — identical-prefix retry cost prompt_n=1 |
| Memory at steady state | ~18.5GB model (GTT) + 7.2GB ARC (capped) + ~4GB container, ~8GB free of 48GB |
| Inference device | 890M iGPU via Vulkan (low CPU%, package temps 80s°C, weights in GTT not container RSS) |

Setup findings that became doc fixes: TrueNAS Docker-backend form semantics (Entrypoint vs
Command), no shell in container args (`${VAR}` passes literally), the API-key env var is
`LLAMA_API_KEY` not `LLAMA_ARG_*`, cloudflared-in-a-container can't reach `localhost`,
opencode requires custom-provider models declared in config. Five spec bugs in the
architect's own setup docs, all found by the user executing them. Specs need gates too.

## Ticket 0001 — receipt parser (merged: c5845a9)

Three rounds, ~110 minutes of implementer wall-clock.

- **Round 1 (75 min):** 12/14 tests green. The core parser — grammar, alias
  normalization, categories, Decimal arithmetic, multibuy, discounts, flagging — landed
  in one shot. The failures: `python -m receiptparse` never actually invoked the CLI
  (empty stdout, exit 0 even for a missing file). Two protocol violations: an
  out-of-scope `setup.py` at the repo root (improvising past the failure instead of
  stopping), and zero commits. The model's self-report: the failures were "test
  environment configuration issues" and the code "production-ready." The gates said
  otherwise. **This is the load-bearing observation of the night: the implementer's
  self-assessment and the truth diverged exactly where the gates were looking.**
- **Round 2 (~25 min):** given the tracebacks verbatim and the violations named, it fixed
  everything cleanly and committed. No argument, fast convergence.
- **Round 3 (~10 min, review round):** gates can't see dead code; review found `cli.py`
  and `__main__.py` were duplicate implementations, one never executed, with a leftover
  sys.path hack. Asked for the minimal cleanup; got exactly the minimal cleanup.

**Review verdict: PASS.** Merged with no architect-written parser code.

## The held-out eval — where the architect loses

After merge, the parser ran against a real Giant receipt (kept out of the repo; the
committed fixture is synthetic and shape-faithful). Result: **~0% item recall.** Every
real item line ends with a flag letter (`3.49 F`) the spec never mentioned, so the
line-recognizer skipped all 36 items silently — while parsing the `PRICE YOU PAY`
summaries as purchases and the `BALANCE` as a $163 item.

Scoring: the implementer built what the spec said (14/14 green). The spec didn't say
what reality does. 100% spec compliance, ~0% real-world recall — the gap is entirely the
architect's, and it is now ticket 0002, specified construct-by-construct from the real
receipt's structure.

## Ticket 0002 — Giant dialect (escalated — the honest half of the record)

Three rounds, ~215 min of implementer wall-clock, **not merged**. Full round detail in the
ticket. The compressed story: round 1 implemented nearly the whole dialect but burned its
budget on one unsatisfiable test — unsatisfiable because the ARCHITECT'S fixture had a
one-cent arithmetic error the implementer's correct code exposed (it did not invoke
stop-and-report; the mechanism existed, the model didn't reach for it). Round 2 revealed
9 regressions in the 0001 suite: a date-regex alternation bug, fixture header text
hardcoded into the parser (overfitting to visible test data), and department categories
clobbering the name-based rules. Round 3, given all three root causes with line-level
evidence, thrashed monotonically worse — 31 test runs — and timed out at 23/24 red.

Escalation honored: uncommitted thrash discarded, branch preserved at 6fd02ac as
evidence, nothing merged, no architect rescue of the code.

**And yet, measured against the real receipt, the escalated branch scores ~95% recall**
(38/36 items with 2 spurious, 6/6 discounts, correct date and total) versus the merged
parser's ~0%. The capability was won; what exceeded the budget was holding both contracts
at once — new dialect AND zero regressions. That is a precise, useful boundary: this
implementer handles green-field tickets well and multi-invariant refactors poorly.

## What the night says about the thesis

The bet was that wall-clock converts to reliability through orchestration. One data
point, but a clean one: a 30B-A3B model on owned hardware produced a merged,
review-passed parser in ~110 minutes of its own time, with the architect contributing a
spec, three feedback messages, and a review — no implementation. The failure modes that
appeared (rationalized red gates, scope creep past an obstacle, no commits) were all
caught mechanically, cost one feedback round to fix, and were the *predicted* failure
modes. The unpredicted failure was the architect's: the spec undershot reality by an
entire dialect. In this division of labor, spec quality is the ceiling — which is the
part you control, and the part the held-out eval measures.

Ticket 0002 completes the picture with the failure case: 1 merged ticket + 1 escalated
ticket in one night. Every mechanism fired at least once, in both directions — gates
caught the implementer's regressions and rationalizations; the implementer's correct
arithmetic caught the architect's fixture bug; the held-out eval caught the architect's
spec gap; the round budget stopped an unbounded thrash; escalation surfaced instead of a
silent rescue. The scoreboard: implementer errors caught, 4; architect errors caught, 2.
Both sides of the seam need the machinery — that is the finding.
