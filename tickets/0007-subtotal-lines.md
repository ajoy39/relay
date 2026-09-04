# Ticket 0007 — SUBTOTAL lines

| | |
|---|---|
| **Status** | open |
| **Scope** | `parser/src/**` only |
| **Acceptance** | `scripts/gates.sh` prints `GATES: GREEN` (all prior tests plus `test_probe_subtotal.py`) |
| **Budget** | 1 dispatch round |

## Goal

Some receipts print a `SUBTOTAL` line before `TAX`. Handle it.

## The construct

A line whose text begins `SUBTOTAL` followed by an amount is informational —
the same treatment `PRICE YOU PAY` already receives. It is not an item and does
not participate in the total check.

## Invariants

All prior tests stay green and untouched. Decimal end-to-end. Stdlib only.
Nothing outside `parser/src/`.

## Stop-and-report conditions

Any apparent contradiction between this spec and a test, or between two tests;
any need to touch a test, fixture, or a path outside `parser/src/`. Report the
problem precisely and stop — that is the correct move, not a failure.

## Reports

(per round)

## Outcome

(architect fills)
