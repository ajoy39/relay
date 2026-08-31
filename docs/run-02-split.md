# Run 02 — the split-ticket experiment

Daytime run, 2026-08-31, same rig as [first-run.md](first-run.md). Question on
trial: did ticket 0002 escalate because the *model* couldn't do the work, or
because the *ticket* was too big? Method: split 0002's ten constructs into three
one-concern tickets (0003 line recognition, 0004 department headers, 0005
quantities/noise + the original full-dialect integration suite as the final gate),
run the loop on each, measure rounds.

## Result

| Ticket | Rounds to green | Path |
|---|---|---|
| 0003 | 3 red (edit framing) → **1 green (rewrite framing)** | escalated as edit; landed as rewrite |
| 0004 | **1** | clean first round |
| 0005 | **1** | clean first round, full integration suite green |

Held-out eval, real Giant receipt: **36/36 items, 6/6 discounts, date correct,
subtotal+tax == printed balance to the penny.** From ~0% (ticket 0001's merged
parser) to 100%.

## Findings, in the order they were earned

1. **Round-time floor: ~75–90 min.** Two 45-minute attempts starved — the agentic
   loop's file-reading and re-prefill overhead at 15 tok/s consumes ~45 min before
   implementation begins. Short "cleanup rounds" only work when the model inherits
   a warm tree. Budget 90 min per round for this rig.
2. **Greenfield ≫ brownfield — the central finding.** Writing a parser from
   scratch: one good round (0001, and again 0003-as-rewrite, 0004, 0005).
   *Modifying* the existing parser in place: 0 for 6 across tickets 0002/0003,
   every attempt ending worse than it started.
3. **Feedback altitude has a ladder, and reframing beats all of it.** Spec prose
   (ignored — 0003's spec named the exact date-regex bug in bold and the model
   wrote the bug anyway) < gate output < named root causes < line-level pseudocode
   (still failed!) < **changing the task shape from "edit" to "rewrite"** (one
   round, green). The operational rule: for this implementer, spec brownfield
   changes as rewrites of the smallest module that contains them.
4. **Small tickets didn't fix editing, but they made everything else work**: red
   surfaces stayed legible (0004 opened with exactly one failing test), rewrites
   stayed tractable, reviews stayed small, and the three tickets provably compose
   — 0005's gate was the untouched 0002 integration suite.
5. **Persistent discipline gaps, priced in**: ends-at-green-without-committing
   (every green round; architect commits with a note), and stop-and-report is
   still never invoked spontaneously. These are handling costs, not blockers.
6. **Best-of-2 remains untested.** The one attempt at it was spoiled by the
   45-minute starvation (both arms starved identically — a time-floor data point,
   not a variance one).

## Revised operating manual for qwen3-coder-30b as implementer

- One concern per ticket; acceptance tests written so the red surface is small.
- Frame implementation as building or rebuilding a module, never as surgery.
- 90-minute rounds; expect 1 round for a well-framed ticket, budget 2.
- Treat the model's self-report as unreliable in both directions (it declared
  false victory on 0001 and false defeat — silence — on contract contradictions).
  The gates and the diff are the only report.
- Architect fixtures get their arithmetic verified programmatically before commit
  (the one-cent bug cost a 100-minute round).

## Open experiments

Bigger implementer (Qwen3-Next-80B-A3B on 96GB, or the M2 Max serving ad hoc) —
does it close the edit-vs-rewrite gap and the self-report gap? Best-of-n at
proper budgets. Speculative decoding for round-time, once capability questions
are settled.
