# Ticket 0005 — Giant dialect, part 3: quantity prefixes, noise tokens, integration

| | |
|---|---|
| **Status** | open |
| **Scope** | `parser/src/**` only |
| **Acceptance** | `scripts/gates.sh` GREEN (everything prior + `test_receipts_giant.py`, the full-dialect integration suite) |
| **Budget** | 3 dispatch rounds |

## Goal

Last of the 0002 split: quantity prefix lines, noise tokens, and the full-dialect
integration fixture (`giant_dialect.txt`) that combines every construct from
tickets 0003–0005.

## Invariants

As before: all prior tests green and untouched; Decimal; stdlib; nothing outside
`parser/src/`; no fixture literals in the parser.

## Approach note (from ticket 0003)

You MAY rewrite parser.py wholesale if simpler than editing. All prior tests
remain the contract.

## The constructs

1. **Standalone multibuy prefix.** A line of the form `N @ PRICE` alone (e.g.
   ` 2 @ 2.50`) sets qty=N for the **next** item line, which carries the extended
   total. Inline `N @ PRICE` inside an item line (ticket 0001) still works.
2. **Weight prefix lines.** A line like ` 1.52 lb @ 0.79 /lb` is informational:
   ignore it entirely; the following item keeps qty=1 (fractional qty is a
   non-goal; the schema's qty stays int).
3. **Noise tokens in names.** Drop tokens `SB` and `NP`; drop a leading `WT`
   token; strip a leading `+` from a name token. New aliases: `YOGRT` → yogurt,
   `PLN` → plain, `KTL` → kettle, `SPRK` → sparkling, `8Z` → 8 oz. Existing
   alias table otherwise unchanged.

## Non-goals

OCR; fractional quantities; other stores' dialects.

## Stop-and-report conditions

As tickets 0003/0004.

## Reports

(per round)

## Outcome

(architect fills on merge)
