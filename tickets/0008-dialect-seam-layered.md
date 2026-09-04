# Ticket 0008 — the dialect seam, layered (supersedes 0006's structure)

| | |
|---|---|
| **Status** | merged (65ace1a) — 4/4 green across independent trials |
| **Scope** | `parser/src/**` only |
| **Acceptance** | `scripts/gates.sh` prints `GATES: GREEN` — all 35 prior tests plus `test_dialect_seam.py` |
| **Budget** | 1 dispatch round per trial |

## Goal

Identical to ticket 0006: a dialect seam so a new store's grammar can be added
without editing existing files. Ticket 0006's spec left the layering implicit,
and every attempt produced a circular dependency between `parser.py` and the
dialects module. This ticket specifies an **acyclic layering** instead. Same
tests, same behaviour, no cycles.

## The layering (strict — imports flow one way only)

```
receiptparse/parser.py     imports NOTHING from receiptparse.dialects
receiptparse/dialects.py   imports FROM parser.py
receiptparse/__init__.py   imports from both, and defines the router
```

1. **`parser.py`** — keep `Item`, `Receipt`, and every existing helper exactly
   where they are. Rename today's `parse_receipt` body to `parse_generic(text)`.
   Do **not** import the dialects module here, at module level or inside a
   function.
2. **`dialects.py`** (a single flat module is fine — no package directory
   needed) — `from receiptparse.parser import parse_generic`, then:
   - `class GenericDialect` — `name = "generic"`, `matches()` returns True
     always (last resort), `parse()` returns `parse_generic(text)`.
   - `class GiantDialect` — `name = "giant"`, `parse()` returns
     `parse_generic(text)`, and `matches()` is a **structural** test: any line
     whose stripped text starts with `BALANCE` after leading `*`, or any line
     containing `PRICE YOU PAY`, or any item line ending in an amount followed
     by a single capital letter token (e.g. `4.19 F`).
   - `_registered = []`, `register_dialect(d)` appends to it.
   - `detect_dialect(text)` — checks `_registered` first (newest first), then
     `GiantDialect()`, then `GenericDialect()`; returns the first whose
     `matches(text)` is True.
3. **`__init__.py`** — the router lives here:
   ```
   from receiptparse.dialects import detect_dialect, register_dialect
   def parse_receipt(text):
       return detect_dialect(text).parse(text)
   __all__ = ["parse_receipt", "register_dialect"]
   ```
   No dialect may ever call `parse_receipt` — that is what caused the recursion
   in earlier attempts.

## Invariants

- `from receiptparse.parser import Item, Receipt` keeps working.
- `from receiptparse import parse_receipt` keeps working.
- `from receiptparse.dialects import detect_dialect, register_dialect` works.
- All 35 prior tests green and untouched. Decimal end-to-end. Stdlib only.
- Nothing outside `parser/src/`. Do not create `setup.py` or `pyproject.toml`;
  the tests are run by `scripts/gates.sh`, which sets `PYTHONPATH` for you.
  If a bare `pytest` invocation fails to import `receiptparse`, that is
  expected — use `scripts/gates.sh`.

## Stop-and-report conditions

Any apparent contradiction between this spec and a test; any need to touch a
test, fixture, or a path outside `parser/src/`. Report precisely and stop.

## Reports / Outcome

(architect fills)
