# Ticket 0004 — Giant dialect, part 2: department headers

| | |
|---|---|
| **Status** | merged (1 round, review PASS; architect committed at green) |
| **Scope** | `parser/src/**` only |
| **Acceptance** | `scripts/gates.sh` GREEN (0001 suite + test_giant_lines.py + test_giant_departments.py) |
| **Budget** | 3 dispatch rounds |

## Goal

Second of the 0002 split. One concern: **department header lines set the category
for the items that follow.** Nothing else changes.

## Invariants

As ticket 0003: prior tests green and untouched; Decimal; stdlib; nothing outside
`parser/src/`; **no fixture literals in the parser** (structural recognition only).

## Approach note (from ticket 0003)

You MAY rewrite parser.py wholesale if that is simpler than editing — ticket 0003
landed green only under rewrite framing. All prior tests remain the contract.

## The construct

1. A **department header** is a line consisting only of capital letters, spaces,
   hyphens, and asterisks — no digits, no trailing amount (e.g. `DAIRY`,
   `FROZEN FOOD`, `BAKERY - COMMERCIAL`). It is not an item.
2. Category map (match on the first word): `BAKERY` → bakery, `DAIRY` → dairy,
   `DELI` → meat, `FROZEN` → frozen, `GROCERY` → pantry, `MEAT` → meat,
   `PRODUCE` → produce; any other header → `other`.
3. While a section is open, the header's category **wins** over name-based rules
   for non-discount items. Items appearing before the first header keep using the
   ticket-0001 name-based rules. Discount lines keep category `discount` always.
4. Store-header noise (name/address lines at the top) must not become sections or
   items: they fail the item test (no trailing amount) and, if they match the
   header shape (e.g. `CORNER MART`), they simply open a section whose category
   (`other`) is irrelevant because a real department header follows before items —
   EXCEPT items before any *mapped* header. Simplest correct rule: a header line
   only opens a section if the receipt has already produced its date line OR the
   header's first word is in the category map; otherwise ignore the line. (The
   fixture exercises exactly this: `CORNER MART` precedes the date and must not
   capture the `OJ` item into a section.)

## Non-goals

Standalone multibuy, weight lines, new aliases (ticket 0005).

## Stop-and-report conditions

As ticket 0003 — contradictions reported, not bulldozed.

## Reports

(per round)

## Outcome

(architect fills on merge)
