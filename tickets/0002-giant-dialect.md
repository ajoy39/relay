# Ticket 0002 — Giant-dialect receipts

| | |
|---|---|
| **Status** | open |
| **Scope** | `parser/src/**` only |
| **Acceptance** | `scripts/gates.sh` prints `GATES: GREEN` (all of `parser/tests/`, including the original ticket-0001 tests) |
| **Budget** | 3 dispatch rounds |

## Goal

Ticket 0001's parser passed its gates, then scored ~zero recall against a real
Giant supermarket receipt: every real item line was silently skipped, and summary
lines were parsed as purchases. This ticket extends the parser to handle the Giant
dialect, specified below from an actual receipt's structure (the fixture
`parser/tests/fixtures/giant_dialect.txt` is synthetic but shape-faithful).

## Invariants

- Everything ticket 0001 requires still holds; its tests stay green untouched.
- All money stays `decimal.Decimal`. Stdlib only. No new files outside `parser/src/`.
- No silent data loss: a line that looks like an item but can't be parsed is
  flagged, not dropped.

## The dialect (each construct is exercised by the fixture and tests)

1. **Flag-letter suffixes.** Item lines end with an amount **followed by a single
   letter code** (`F`, `T`, `B`, …): `SB WHOLE MILK  NP  3.49 F`. Strip the code;
   the amount is the line total. Lines ending in a bare amount (ticket 0001 style)
   must still parse.
2. **Trailing-minus discounts.** `BONUS BUY SAVINGS  1.30-F` is a discount:
   line_total **-1.30**, category `discount`, not flagged. The trailing letter may
   follow the minus.
3. **Summary lines are not items.** Lines beginning `PRICE YOU PAY` are
   informational and must be ignored entirely (counting them double-counts).
4. **`**** BALANCE` is the total.** Treat a line whose text (ignoring leading `*`
   and whitespace) starts with `BALANCE` exactly like `TOTAL`. `TAX` is unchanged.
5. **Department headers set category.** A line consisting only of an
   all-caps department name (no trailing amount) starts a section. Map:
   `BAKERY*` → bakery, `DAIRY` → dairy, `DELI` → meat, `FROZEN*` → frozen,
   `GROCERY` → pantry, `MEAT` → meat, `PRODUCE` → produce; any other header →
   `other`. While a section is open, **the header's category wins** over
   ticket 0001's name-based rules; name-based rules still apply to any items seen
   before the first header. Discount lines keep category `discount` regardless.
6. **Two-digit years.** Header dates may be `MM/DD/YY` → `20YY-MM-DD`.
   `MM/DD/YYYY` still works.
7. **Standalone multibuy prefix.** A line of the form `N @ UNITPRICE` on its own
   (e.g. ` 2 @ 2.50`) sets qty=N for the **next** item line, which carries the
   extended total. Inline `N @ UNIT` within an item line (ticket 0001) still works.
8. **Weight prefix lines.** A line like ` 1.52 lb @ 0.79 /lb` is informational:
   ignore it; the following item keeps qty=1 (fractional quantities are a
   non-goal — the schema's qty stays int).
9. **Noise tokens.** In item names: drop tokens `SB` (store brand), `NP`, and a
   leading `WT`; strip a leading `+` from a name token. New aliases:
   `YOGRT` → yogurt, `PLN` → plain, `KTL` → kettle, `SPRK` → sparkling,
   `8Z` → 8 oz. (Existing alias table otherwise unchanged.)

## Non-goals

- OCR. Input is already text.
- Fractional quantities (see 8).
- Any other store's dialect. One dialect per ticket.

## Stop-and-report conditions

- A construct in the fixture that this spec doesn't cover.
- Any apparent conflict between this spec, the 0001 spec, or any test.
- Needing to touch anything outside `parser/src/`.

## Reports

(append here per round)

## Outcome

(architect fills on merge)
