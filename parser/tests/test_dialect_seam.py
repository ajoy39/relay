"""Acceptance tests for ticket 0006 — the dialect seam.

Read-only to the implementer. These tests define the EXTENSION CONTRACT: a new
store's dialect must be addable without editing any existing parser file.
The 35 prior tests remain the behavioural contract and must stay green.
"""
from decimal import Decimal
from pathlib import Path

import pytest

from receiptparse import parse_receipt
from receiptparse.dialects import detect_dialect, register_dialect

FIXTURES = Path(__file__).parent / "fixtures"


def read(name):
    return (FIXTURES / name).read_text()


# ------------------------------------------------------------------ detection

def test_detect_returns_named_dialects():
    giant = detect_dialect(read("giant_dialect.txt"))
    generic = detect_dialect(read("basic.txt"))
    assert giant.name != generic.name
    assert "giant" in giant.name.lower()


def test_detection_is_stable_across_giant_fixtures():
    names = {detect_dialect(read(f)).name
             for f in ("giant_dialect.txt", "giant_flat.txt", "giant_departments.txt")}
    assert len(names) == 1


def test_generic_fixtures_all_detect_generic():
    names = {detect_dialect(read(f)).name
             for f in ("basic.txt", "multibuy_discount.txt", "mismatch.txt",
                       "gnarly.txt", "no_date.txt")}
    assert len(names) == 1


# ------------------------------------------------------------ the actual seam

MOON_RECEIPT = """MOONMART LUNAR BRANCH
== 2026-04-01 ==
milk :: 3.00
bread :: 2.00
== TOTAL 5.00 ==
"""


class MoonDialect:
    """A third-party dialect defined entirely outside the package."""

    name = "moonmart"

    def matches(self, text):
        return "MOONMART" in text.splitlines()[0] if text.strip() else False

    def parse(self, text):
        from receiptparse.parser import Item, Receipt
        items, total, date = [], None, None
        for raw in text.splitlines():
            line = raw.strip()
            if line.startswith("== TOTAL"):
                total = Decimal(line.split()[2])
            elif line.startswith("=="):
                date = line.split()[1]
            elif "::" in line:
                name, amount = (p.strip() for p in line.split("::"))
                items.append(Item(raw=raw, name=name, category="other", qty=1,
                                  line_total=Decimal(amount), flagged=False))
        subtotal = sum((i.line_total for i in items), Decimal("0"))
        return Receipt(date=date, tax=Decimal("0"), total=total,
                       total_matches=(total is not None and subtotal == total),
                       items=items)


@pytest.fixture
def moon_registered():
    d = MoonDialect()
    register_dialect(d)
    yield d


def test_registered_dialect_is_detected(moon_registered):
    assert detect_dialect(MOON_RECEIPT).name == "moonmart"


def test_registered_dialect_drives_parse_receipt(moon_registered):
    r = parse_receipt(MOON_RECEIPT)
    assert r.date == "2026-04-01"
    assert r.total == Decimal("5.00")
    assert r.total_matches is True
    assert [i.name for i in r.items] == ["milk", "bread"]


def test_registration_does_not_disturb_builtins(moon_registered):
    r = parse_receipt(read("basic.txt"))
    assert r.date == "2026-08-12"
    assert r.total_matches is True
    assert detect_dialect(read("giant_dialect.txt")).name != "moonmart"
