# Ticket 0001 — receipt parser

**Status**: ready
**Scope (writable paths)**: `parser/src/**` only
**Acceptance command**: `scripts/gates.sh` (must exit 0)
**Dispatch budget**: 3 rounds, then escalate

## Goal

A Python package `receiptparse` that turns grocery-receipt text into structured line items with
normalized names and categories, plus a CLI that emits CSV. Downstream consumer: a personal
cost-tracking system that stores receipt photos and parses them on demand ("retain raw, parse on
query") — this parser is the parse-on-query half, operating on already-OCR'd text.

## Invariants

- Pure Python 3.11+, **standard library only**. Money is `decimal.Decimal` end to end — a float
  anywhere in a money path is a defect even if tests pass.
- Unreadable input degrades loudly, never silently: a garbage line becomes a **flagged** item,
  never a dropped one. The consumer must be able to see what wasn't parsed.
- The acceptance tests in `parser/tests/` are the contract and are **read-only** to the
  implementer, as is this ticket.

## Non-goals

- No OCR — input is text (OCR happens upstream).
- No persistence, no network, no receipt formats beyond the grammar below.
- No third-party dependencies, no cleverness with locale/currency (USD, `.` decimal).

## Specification

### Package layout and API

`parser/src/receiptparse/` importable with `PYTHONPATH=parser/src` (gates set this). Public API:

```python
from receiptparse import parse_receipt   # (text: str) -> Receipt

Receipt:  date: str | None      # ISO "YYYY-MM-DD"
          tax: Decimal          # 0 if absent
          total: Decimal | None
          total_matches: bool   # sum(non-flagged item line_totals) + tax == total, ±0.01
          items: list[Item]

Item:     raw: str              # the line as seen, stripped
          name: str             # normalized (below)
          category: str
          qty: int              # default 1
          line_total: Decimal | None   # signed; None only if unparseable
          flagged: bool
```

### Input grammar (line-oriented)

- **Header noise**: leading lines with no trailing money amount (store name, address) — ignore.
- **Date**: first line containing `MM/DD/YYYY` → `date` (time ignored). Absent → `None`.
- **Item line**: `NAME  AMOUNT` (amount = last token, optional `-`). Multi-buy `N @ UNIT` inside
  the name sets `qty=N`; `line_total` is always the trailing amount as printed.
- **Discount**: any body line with a negative amount → normal item, `category="discount"`.
- **Garbage**: a body line whose name portion contains **no ASCII letters** → `flagged=True`,
  `category="other"`, name = raw lowercased, excluded from the `total_matches` sum.
- **`TAX AMOUNT`** → `tax`, not an item. **`TOTAL AMOUNT`** → `total`, not an item; parsing of
  items stops after TOTAL.

### Name normalization

Lowercase; split on whitespace; expand each token via the alias table; drop tokens marked (drop);
rejoin preserving order. The table is the complete vocabulary the tests use:

| token | → | token | → |
|---|---|---|---|
| WHL MLK *(pair)* | whole milk | GRND | ground |
| 1GAL | 1 gallon | CPN | coupon |
| LG | large | SPARK | sparkling |
| DZ | dozen | 12PK | 12 pack |
| GRK | greek | OJ | orange juice |
| 64OZ | 64 oz | FRZ | frozen |
| GV | *(drop — store brand)* | BNLS | boneless |
| CHKN | chicken | BRST | breast |
| RSTD | roasted | GRLC | garlic |
| HMMS | hummus | PPR | paper |
| TWLS | towels | 6RL | 6 roll |
| 2L | 2 liter | | |

Unknown tokens pass through lowercased (`bananas` → `bananas`, `2%` → `2%`).

### Categories

First matching rule wins, checked against the normalized name:

1. negative amount → `discount`
2. flagged → `other`
3. contains `frozen` → `frozen`
4. contains `milk`, `yogurt`, or `eggs` → `dairy`
5. contains `chicken` → `meat`
6. contains `bread` → `bakery`
7. contains `coffee`, `water`, `juice`, or `soda` → `beverage`
8. contains `paper` or `towels` → `household`
9. contains `bananas`, `apples` → `produce`
10. contains `hummus` → `pantry`
11. else → `other`

### CLI

`python -m receiptparse FILE [FILE...]` → CSV on stdout, header
`date,raw,name,category,qty,line_total,flagged`, one row per item, files in argument order.
`line_total` empty string when `None`; `flagged` as `true`/`false`; fields quoted per `csv`
module defaults. Exit 0 on success, 2 with a stderr message if a file is missing.

## Acceptance

`scripts/gates.sh`: pytest over `parser/tests/`, which exercises every fixture in
`parser/tests/fixtures/` against the exact values above, plus the CLI via subprocess.

## Stop-and-report conditions

Standard set (see TEMPLATE), plus: any fixture that appears to contradict the grammar or alias
table above — report it, don't special-case it.

## Reports

*(empty — awaiting first dispatch)*

## Outcome

*(pending)*
