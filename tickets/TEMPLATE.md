# Ticket NNNN — <name>

**Status**: draft | ready | in-progress | review | merged | escalated
**Scope (writable paths)**: <the ONLY paths the implementer may modify>
**Acceptance command**: `scripts/gates.sh` (must exit 0)
**Dispatch budget**: 3 rounds, then escalate

## Goal

<One paragraph. What exists when this is done, and who it's for.>

## Invariants

<Things that must remain true — the constraints the implementation may not trade away.
These are the lines a weaker implementer would otherwise bulldoze through.>

## Non-goals

<Explicitly out of scope. As load-bearing as the goal: this is where accidental scope creep
gets pre-refused.>

## Specification

<The details. Formats, schemas, behaviors, edge cases. Anything testable here should have a
matching acceptance test — a requirement without a test is a hope.>

## Acceptance

<How the gates verify this ticket, in prose. The tests themselves live in the repo and are
part of this spec — the implementer runs them, and MUST NOT edit them.>

## Stop-and-report conditions

Stop, write the problem under `## Reports`, and exit — do not improvise past any of these:

- The spec contradicts itself, or a test demands what the spec forbids
- The change wants to touch a path outside the scope above
- A dependency or tool is missing
- <ticket-specific tripwires>

## Reports

<Implementer writes here. Architect responds here. The ticket is the conversation.>

## Outcome

<Filled at merge/escalation: rounds used, wall-clock, what the next spec should learn.>
