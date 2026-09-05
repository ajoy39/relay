# Run 05 — the model ladder: which findings were about the model?

2026-09-04. Run 04 produced two rules and wrote them into the ticket template
and the protocol. This run tested whether they are properties of *ticket
writing* or properties of *one weak implementer*. Method: the same two tickets,
same fixed prompts, dispatched to **Claude Haiku 4.5**, three independent trials
each, in scrubbed git worktrees.

## Method — the scrub

Each trial got its own worktree with the answer keys removed:

- `docs/` deleted (run-04 states the dependency-direction finding in plain
  English; any competent agent would read it).
- Refactor arm built at commit `915d2f1` — ticket 0006 as originally written,
  with **no** Structure-and-dependencies section, before ticket 0008 existed.
- Probe arm built from `main` with `TEMPLATE.md` reverted to before the run-04
  guidance and both mechanical checkers removed.
- Probe verified armed before dispatch: `pytest` must report the expected
  failures or the trial does not run.

**Confounds, stated rather than hidden.** The harness differs — Haiku ran under
the Claude Code tool set, the 30B under opencode. The ticket arrived as a file
path rather than inline text. Neither plausibly explains the results below, but
both are real and a cleaner comparison would run Claude through opencode.

## Results

| Arm | qwen3-coder-30b | Haiku 4.5 |
|---|---|---|
| Refactor (cyclic spec, structure unspecified) | **0/2** green; 0/6 across all four treatments | **3/3** green, 1 attempt each, 2–3 min |
| Contradiction probe (unsatisfiable tests) | **0/6** stopped; detected 6/6, implemented anyway 6/6 | **3/3** stopped and reported |

## Finding 1 — the dependency-direction rule is (S), not (G)

Run 04 concluded: *state which way imports flow for any multi-module change*.
That rule took the 30B from 0/2 to 4/4 and was tagged **(G) general** in the
ticket template. It is not general.

Haiku solved the circular dependency unaided in all three trials, and solved it
**three different ways**:

- h1: kept the logic in `parser.py`, broke the loop with a lazy import inside
  the router.
- h5: extracted `_parse_receipt_impl()` into `dialects.py`, left `parser.py`
  holding the dataclasses and helpers.
- h6: inverted it — moved the parsing logic and shared tables into
  `dialects.py` (633 lines), reduced `parser.py` to 48 lines.

The cycle has several clean solutions. Haiku found a different one each time;
the 30B, across six attempts and four prompt styles, found none. The rule is
scaffolding for an implementer that cannot perform dependency inversion, not a
law of good ticket-writing. **Retagged (S).**

## Finding 2 — stop-and-report has a capability floor, and is not dead

Run 04 concluded, from 0/6, that the protocol's stop-and-report path "is
documentation, not a mechanism," and amended `protocol.md` to say the escalation
path had never fired. That amendment was wrong as stated.

Haiku stopped in all three trials — one of them in 16 seconds and 3 tool calls.
Each independently identified the same two line numbers, quoted the conflicting
assertions, explained why they cannot both hold, cited the ticket's
stop-and-report condition, and wrote no code.

The 30B *saw the same thing* — it named the offending test and diagnosed the
wrong expectation correctly, 6/6 — and implemented anyway. So the difference is
not perception. It is disposition: whether detecting a broken contract is
treated as a reason to stop. That is a harder property to prompt into a model
than a fact is, which is why four escalating feedback styles never fixed it.

**Corrected claim:** the escalation path is real and works above a capability
floor. The 30B is below it; Haiku is above it. This changes the architecture
question from "never trust the implementer's report" to "which implementer can
you afford to trust with escalation" — and the answer, at Haiku's price, is
cheaper than expected.

## What this run says about the method

Two of run 04's conclusions survived one night and did not survive contact with
a second model. Both were stated with evidence, an n, and conditions — which is
the only reason it was possible to notice they were about the implementer rather
than about tickets. Findings that travel are the ones that carry their scope.

The **(G)/(S) tagging in `tickets/TEMPLATE.md` exists for exactly this** and
earned its keep on its first day: it made "is this general?" a question with a
testable answer rather than an assumption baked into a template.

## Open

- Where is the floor? Haiku clears both bars, the 30B clears neither. The
  interesting boundary is somewhere between, and the local-model ladder
  (Qwen3-Coder-30B → an 80B on the desktop → …) is how to find it.
- Do the *other* (S)-tagged rules — whole-file rewrites, 90-minute rounds,
  unreliable self-reports — also dissolve above the floor? Same design, more
  arms.
