# Ticket 0003 — Giant dialect, part 1: line recognition

| | |
|---|---|
| **Status** | open |
| **Scope** | `parser/src/**` only |
| **Acceptance** | `scripts/gates.sh` prints `GATES: GREEN` (all of `parser/tests/` — the 14 ticket-0001 tests AND `test_giant_lines.py`) |
| **Budget** | 3 dispatch rounds |

## Goal

First of three tickets splitting the escalated ticket 0002 into one concern each.
This ticket: **which lines are items, and what is their amount** — nothing else.
Departments, multibuy prefixes, weight lines, and new aliases are tickets 0004/0005:
do NOT implement them here.

## Invariants

- The 14 ticket-0001 tests stay green, untouched. Lines ending in a bare amount
  (0001 style) must keep parsing exactly as before.
- All money `decimal.Decimal`. Stdlib only. No files outside `parser/src/`.
- **No fixture text in the parser.** Store names, addresses, or any literal from a
  fixture appearing in parser source is an automatic review reject. Recognition is
  structural: a line that doesn't match a construct below is simply ignored.

## The constructs (all exercised by `giant_flat.txt`)

1. **Flag-letter suffixes.** An item line may end with an amount followed by a
   single letter code: `WHL MLK 1GAL   4.19 F`. Strip the letter; the amount is
   the line total. Existing behavior (bare amount, garbage-with-amount → flagged,
   no-amount → not an item) is unchanged otherwise.
2. **Trailing-minus discounts.** `BONUS BUY SAVINGS   1.20-F`: amount with a
   trailing minus (letter code may follow the minus) is a discount — line_total
   **-1.20**, category `discount`, not flagged.
3. **Summary lines.** Lines starting `PRICE YOU PAY` are ignored entirely.
4. **BALANCE is TOTAL.** A line whose text after leading `*` and whitespace starts
   with `BALANCE` is the receipt total, exactly like `TOTAL`.
5. **Two-digit years.** `MM/DD/YY` → `20YY-MM-DD`. `MM/DD/YYYY` still works — try
   the 4-digit pattern FIRST (alternation order: a 2-digit-first regex eats
   '08/12/2026' as '08/12/20').

## Non-goals (later tickets — implementing them here is scope creep)

Department headers (0004). Standalone multibuy prefix lines, weight lines,
noise-token aliases (0005).

## Stop-and-report conditions

Any apparent contradiction between this spec, the 0001 spec, or any test — report
it precisely and stop; that is the winning move, not a penalty. Also: needing any
path outside `parser/src/`.

## Reports

(per round)

## Outcome

(architect fills on merge)
