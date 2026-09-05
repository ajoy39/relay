# Run 06 — independent tests of every remaining rule

2026-09-04, immediately after run 05. Run 05 retagged two rules from general to
small-model-specific. This run tests the rest of the `(S)` list, each
independently, against Claude Haiku 4.5.

**Instrumentation note, and a correction.** In run 05 the agents' reports of
"GATES: GREEN" were accepted at face value and the worktrees deleted without
independent verification — while one of the rules under test is *treat
self-reports as unreliable*. That was the architect committing the exact error
the rule warns about. In this run every trial's gates were re-run by the
architect, and commit state and test-file cleanliness checked with `git`, not
asked for.

## Design

Six independent trials, one scrubbed worktree each, all built at commit
`2bfec08` — the brownfield state where `test_giant_lines.py` is red (7 failed,
14 passed) and `parser.py` must be *modified* to satisfy it. This is the exact
task the 30B failed 0/6 under edit framing. `docs/` deleted; the "you MAY
rewrite wholesale" approach note stripped from the ticket.

Two arms, differing by **one line** of the dispatch prompt:

- **Rewrite arm (e1–e3):** includes *"build each file you need in one complete
  pass — write whole files rather than patching them incrementally."*
- **Neutral arm (e4–e6):** no approach line at all.

## Results — all six verified by the architect, not self-reported

| Trial | Framing | Gates (architect-run) | Attempts | Commit | Tests touched | `parser.py` diff |
|---|---|---|---|---|---|---|
| e1 | rewrite | GREEN | 1 | yes | no | +101 / −47 |
| e2 | rewrite | GREEN | 1 | yes | no | +98 / −60 |
| e3 | rewrite | GREEN | 1 | yes | no | +83 / −40 |
| e4 | neutral | GREEN | 1 | yes | no | +104 / −42 |
| e5 | neutral | GREEN | 1 | yes | no | +104 / −39 |
| e6 | neutral | GREEN | 1 | yes | no | +88 / −37 |

Baseline for the same task: **qwen3-coder-30b, 0/6 green under edit framing.**

## Rule 1 — "prefer whole-file rewrites over incremental edits": (S), and inert

6/6 green in one attempt regardless of framing. The two arms are
indistinguishable: same outcome, same number of attempts, and diffs that
overlap in range (+83…+104 added, −37…−60 removed).

The sharper finding is in that diff column. **Every trial patched
incrementally — including all three that were explicitly instructed to write
whole files.** On a ~300-line module a genuine rewrite would show roughly
+300/−300. Haiku read the instruction, judged that an edit was the right shape
for this change, and edited anyway.

So the rule is not merely unnecessary above the capability floor — it is
*ignored*, and correctly so. It stays tagged **(S)**, and the template now warns
that it is likely counterproductive for a strong implementer in a large
codebase, where a needless rewrite is review burden and merge-conflict surface.

## Rule 2 — "treat self-reports as unreliable in both directions": (S)

6/6 agent claims matched the architect's independent gate runs exactly. No false
success claims, no unreported failures. Against the 30B's habit of declaring
"production ready" over failing tests and dismissing real failures as "one
unrelated error in a different test file", this is a clean separation.

Caveat kept deliberately: this measures reporting accuracy on tasks that
*succeeded*. The 30B's worst self-reports came from failing rounds. A fair test
of the failure case needs a ticket Haiku cannot complete — not yet run.

## Rule 3 — "expect no commit at green when the round was messy": (S)

6/6 committed at green with the required message format; zero uncommitted
changes left behind; zero test files touched. The 30B needed the architect to
commit on its behalf in several rounds.

## Rule 4 — "budget ~90 minutes per round": (S), and it was never about agents

Answered by runs 05–06 without a dedicated arm: Haiku completed this class of
ticket in 1–3.5 minutes. The 75–90 minute floor is a property of ~15 tok/s on a
NAS, not of agentic implementation work.

## Where this leaves the template

Every rule derived from the 30B is now tagged **(S)** and has been independently
tested at one point above the floor. Nothing in the run-04 findings survived as
general guidance about ticket-writing. What survived is the *method* — fixed
treatments, scrubbed worktrees, armed instruments, architect-verified results —
and the two mechanical checks, which cost nothing and protect against the
architect as much as the implementer.

## Open

- **The failure-case self-report test.** Needs a ticket Haiku genuinely cannot
  finish. Design it so the failure is real rather than contrived.
- **Where the floor sits.** Everything between the 30B and Haiku is unmapped,
  and that is most of the interesting range for local hosting.
- **Whether the rewrite instruction actively harms a strong model in a large
  codebase.** This fixture is a 300-line module; it cannot answer that, and it
  is the version of the question that matters for a real team.
