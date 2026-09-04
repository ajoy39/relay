# Ticket NNNN — <name>

**Status**: draft | ready | in-progress | review | merged | escalated
**Scope (writable paths)**: <the ONLY paths the implementer may modify>
**Acceptance command**: `scripts/gates.sh` (must exit 0)
**Dispatch budget**: 3 rounds, then escalate

> Before dispatching, run `scripts/check_ticket.sh tickets/NNNN-*.md`. It is a
> mechanical pre-flight — it does not read your intent, only whether the ticket
> is dispatchable. Post-dispatch, run `scripts/scan_report.sh <transcript>`.

---

## Goal

<One paragraph. What exists when this is done, and who it's for.>

## Structure and dependencies

<REQUIRED. If this ticket touches more than one module, state which way the
imports flow, e.g. `parser.py <- dialects.py <- __init__.py`, and name where any
new module goes. If it touches exactly one module, write "Single module — not
applicable" and move on.

Why this section exists: a seam specified without a direction produced a
circular dependency in 6/6 attempts (RecursionError or import failure) and
0/2 green rounds; the same ticket with the direction stated went 4/4 green in
10–27 minutes. Run 04.>

## Invariants

<Things that must remain true — the constraints the implementation may not trade
away. These are the lines a weaker implementer would otherwise bulldoze through.>

## Non-goals

<Explicitly out of scope. As load-bearing as the goal: this is where accidental
scope creep gets pre-refused.>

## Specification

<The details. Formats, schemas, behaviours, edge cases. Anything testable here
should have a matching acceptance test — a requirement without a test is a hope.>

## Acceptance

<How the gates verify this ticket, in prose. The tests live in the repo, are part
of this spec, and MUST NOT be edited by the implementer.>

## How to run the tests

Use `scripts/gates.sh`. A bare `pytest` will not import the package (there is
deliberately no `pyproject.toml`); that is expected and is not a packaging
problem. Do not create `setup.py` or `pyproject.toml`.

<Keep this section verbatim unless the repo's test invocation changes. An
implementer that reads an import error as a packaging problem will spend its
entire round on `pip install -e .`; one sentence of orientation turned a total
failure into 39/41 passing. Run 04.>

## If the contract is broken

If any test cannot be satisfied — because two tests demand different things, or
a test contradicts this spec — **say so explicitly in your final message**: name
the tests, state the conflict, and state what you did about it. You may still
implement what is implementable; the report is what matters.

<This asks for what implementers actually do. Detection of a broken contract is
6/6 in controlled trials; stopping on it is 0/6. An instruction to STOP that is
never obeyed teaches the architect to trust an escalation path that does not
exist — the alert-fatigue failure mode. `scripts/scan_report.sh` reads the
transcript for exactly this and exits non-zero. Run 04.>

## Reports

<Implementer writes here. Architect responds here. The ticket is the conversation.>

## Outcome

<Filled at merge/escalation: rounds used, wall-clock, what the next spec should
learn.>

---

## Notes on the guidance in this template

Findings are tagged by how far we think they travel:

- **(G) general** — believed to hold for any implementer, including frontier
  models and humans.
- **(S) suspected small-model-specific** — measured on qwen3-coder-30b, plausibly
  an artifact of a weak implementer. **Candidates for A/B testing against larger
  models and against Claude itself.** Do not assume these transfer.

| Guidance | Tag | Evidence |
|---|---|---|
| State the dependency direction for multi-module changes | **(G)** | 0/2 → 4/4, run 04 |
| Say how to run the tests; pre-refuse the packaging rabbit hole | **(G)** | total failure → 39/41, run 04 |
| One *concern* per ticket — any number of files, provided their relationships are stated | **(G)** | run 02 split; ticket 0008 touched 3 files, green in 12 min |
| Ask for an explicit report of a broken contract rather than a stop | **(G)** | detect 6/6, stop 0/6, run 04 |
| Prefer whole-file rewrites over incremental edits | **(S)** | 4/4 vs 0/6, runs 02+04. Very likely wrong advice for a frontier model in a large codebase |
| Budget ~90 minutes per round | **(S)** | 45-min rounds starve at ~15 tok/s; a faster host changes this entirely |
| Expect the implementer not to commit at green when the round was messy | **(S)** | observed across runs 01–04 |
| Treat self-reports as unreliable in both directions | **(S?)** | strongly observed here; frontier models are better but not immune |

The architect decides how much structure to specify. There is a real line
between *specifying* and *dictating* — specifying the layering meant the
architect did the design and the implementer did the typing. For a weak local
model that trade is worth it; for a strong one it may waste the implementer's
judgement. Left to architect judgement deliberately, pending more examples of it
succeeding and failing.
