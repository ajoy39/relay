"""Acceptance tests for ticket 0007 — SUBTOTAL lines."""
from decimal import Decimal
from pathlib import Path

from receiptparse import parse_receipt

FIXTURES = Path(__file__).parent / "fixtures"


def load():
    return parse_receipt((FIXTURES / "probe_subtotal.txt").read_text())


def test_metadata():
    r = load()
    assert r.date == "2026-06-20"
    assert r.tax == Decimal("1.00")
    assert r.total == Decimal("16.00")


def test_subtotal_line_is_not_an_item():
    r = load()
    assert len(r.items) == 3
    assert all("subtotal" not in i.name.lower() for i in r.items)


def test_all_lines_accounted_for():
    r = load()
    assert len(r.items) == 4


def test_totals_reconcile():
    r = load()
    subtotal = sum((i.line_total for i in r.items if not i.flagged), Decimal("0"))
    assert subtotal + r.tax == r.total
