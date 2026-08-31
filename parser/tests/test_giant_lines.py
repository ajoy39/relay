"""Acceptance tests for ticket 0003 — Giant-dialect line recognition.

Read-only to the implementer. Contract rules as ever: a seemingly contradictory
test is a stop-and-report, not a test edit. The ticket-0001 suite stays green.
"""
from decimal import Decimal
from pathlib import Path

from receiptparse import parse_receipt

FIXTURES = Path(__file__).parent / "fixtures"


def load():
    return parse_receipt((FIXTURES / "giant_flat.txt").read_text())


def test_two_digit_year():
    assert load().date == "2026-06-15"


def test_balance_is_total():
    r = load()
    assert r.tax == Decimal("0.60")
    assert r.total == Decimal("27.06")
    assert r.total_matches is True


def test_flag_suffix_items():
    r = load()
    got = {i.name: i.line_total for i in r.items if not i.flagged and i.line_total > 0}
    assert got == {
        "whole milk 1 gallon": Decimal("4.19"),
        "orange juice 64 oz": Decimal("5.49"),
        "boneless chicken breast": Decimal("7.99"),
        "paper towels 6 roll": Decimal("9.99"),
    }


def test_name_categories_still_apply():
    r = load()
    cat = {i.name: i.category for i in r.items if not i.flagged and i.line_total > 0}
    assert cat["whole milk 1 gallon"] == "dairy"
    assert cat["orange juice 64 oz"] == "beverage"
    assert cat["boneless chicken breast"] == "meat"
    assert cat["paper towels 6 roll"] == "household"


def test_trailing_minus_discount():
    r = load()
    discounts = [i for i in r.items if i.category == "discount"]
    assert len(discounts) == 1
    assert discounts[0].line_total == Decimal("-1.20")
    assert discounts[0].flagged is False


def test_summary_lines_excluded():
    r = load()
    assert len(r.items) == 6  # 4 purchases + 1 discount + 1 flagged
    for i in r.items:
        assert "price you pay" not in i.name
        assert "balance" not in i.name


def test_garbage_flagged_not_dropped_and_excluded_from_total():
    r = load()
    flagged = [i for i in r.items if i.flagged]
    assert len(flagged) == 1
    assert flagged[0].line_total == Decimal("2.22")
    subtotal = sum(i.line_total for i in r.items if not i.flagged and i.line_total is not None)
    assert subtotal + r.tax == r.total
