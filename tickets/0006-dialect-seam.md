# Ticket 0006 — the dialect seam

| | |
|---|---|
| **Status** | superseded by 0008 — its implicit layering induced a dependency cycle; kept as the control condition in run 04 |
| **Scope** | `parser/src/**` only (new files welcome inside `parser/src/receiptparse/`) |
| **Acceptance** | `scripts/gates.sh` prints `GATES: GREEN` — all 35 prior tests plus `test_dialect_seam.py` |
| **Budget** | 3 dispatch rounds |

## Goal

`parser.py` currently handles two receipt grammars — the generic one from ticket
0001 and the Giant dialect from 0003–0005 — interleaved in a single function.
Adding a third store means editing that function again. This ticket introduces
a **dialect seam**: detection plus a registry, so a new store's grammar can be
added *without editing any existing file*.

This is a **refactor**. No user-visible behaviour changes: every one of the 35
existing tests must stay green, untouched, asserting exactly what it asserts now.

## The contract (what the tests require)

A new module `receiptparse.dialects` exposing:

- `detect_dialect(text) -> dialect` — returns the dialect object that should
  handle this text. Falls back to the generic dialect when nothing else matches.
- `register_dialect(dialect)` — adds a third-party dialect. Registered dialects
  take precedence over built-ins; the generic dialect is always the last resort.

A **dialect** is any object with:

- `name: str` — the built-in Giant dialect's name must contain "giant"
  (case-insensitive); the generic one must have a different name.
- `matches(text: str) -> bool`
- `parse(text: str) -> Receipt`

`parse_receipt(text)` must route through `detect_dialect` and delegate.

## Invariants

- `Item` and `Receipt` stay importable from `receiptparse.parser`
  (`from receiptparse.parser import Item, Receipt`), with their current fields.
  `parse_receipt` stays importable from `receiptparse`.
- All 35 prior tests green and untouched. Decimal end-to-end. Stdlib only.
- No fixture literals (store names, addresses) as detection keys beyond what a
  real dialect legitimately keys on — detection must work on *grammar shape* or
  a store's own printed identity, not on fixture-specific noise. Note the Giant
  fixtures do not all share a store name; find something structural.
- Nothing outside `parser/src/`.

## Approach note

You may create new files under `parser/src/receiptparse/` and rewrite
`parser.py` wholesale — prior tickets landed green under rewrite framing and
red under incremental patching. Shared helpers (alias normalisation, category
rules, amount parsing) can live in a module both dialects import; duplicating
them in two dialects is allowed but will be reviewed as a smell.

## Non-goals

New parsing behaviour. New stores. CLI changes. Performance work.

## Stop-and-report conditions

Any apparent contradiction between this spec and a test; any need to touch a
test, fixture, or a path outside `parser/src/`. Report precisely and stop —
that is the correct move, not a failure.

## Reports

(per round)

## Outcome

(architect fills on merge)
