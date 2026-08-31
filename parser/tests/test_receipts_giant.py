"""Acceptance tests for ticket 0002 — the Giant dialect, executable.

Read-only to the implementer. Every expected value below is stated in the ticket's
specification; if a test seems to contradict the ticket, that's a stop-and-report,
not a test edit. The original ticket-0001 tests must stay green alongside these.
"""
from decimal import Decimal
from pathlib import Path

from receiptparse import parse_receipt

FIXTURES = Path(__file__).parent / "fixtures"


def load():
    return parse_receipt((FIXTURES / "giant_dialect.txt").read_text())


def test_two_digit_year_date():
    assert load().date == "2026-07-22"


def test_balance_is_total_and_matches():
    r = load()
    assert r.tax == Decimal("0.42")
    assert r.total == Decimal("32.57")
    assert r.total_matches is True


def test_item_count_and_no_summary_lines():
    r = load()
    # 7 purchases + 2 discounts + 1 flagged garbage line = 10 items.
    assert len(r.items) == 10
    for i in r.items:
        assert "price you pay" not in i.name
        assert "balance" not in i.name


def test_flag_suffix_items_parsed():
    r = load()
    got = [(i.name, i.line_total) for i in r.items if not i.flagged and i.line_total > 0]
    assert ("whole milk", Decimal("3.49")) in got
    assert ("yogurt greek plain", Decimal("5.99")) in got
    assert ("kettle chips 8 oz", Decimal("4.29")) in got
    assert ("sparkling water 12 pack", Decimal("6.99")) in got
    assert ("chicken breast boneless", Decimal("8.49")) in got
    assert ("fresh bananas", Decimal("1.20")) in got
    assert ("avocados", Decimal("5.00")) in got


def test_bonus_buy_lines_are_discounts():
    r = load()
    discounts = [i for i in r.items if i.category == "discount"]
    assert sorted(i.line_total for i in discounts) == [Decimal("-2.00"), Decimal("-1.30")]
    assert all(not i.flagged for i in discounts)


def test_department_header_sets_category():
    r = load()
    cat = {i.name: i.category for i in r.items if not i.flagged}
    assert cat["whole milk"] == "dairy"
    assert cat["yogurt greek plain"] == "dairy"
    assert cat["kettle chips 8 oz"] == "pantry"
    assert cat["sparkling water 12 pack"] == "pantry"  # header wins over name rules
    assert cat["chicken breast boneless"] == "meat"
    assert cat["fresh bananas"] == "produce"
    assert cat["avocados"] == "produce"


def test_standalone_multibuy_sets_qty():
    r = load()
    avo = next(i for i in r.items if i.name == "avocados")
    assert avo.qty == 2
    assert avo.line_total == Decimal("5.00")


def test_weight_line_ignored_qty_stays_one():
    r = load()
    ban = next(i for i in r.items if i.name == "fresh bananas")
    assert ban.qty == 1
    assert ban.line_total == Decimal("1.20")


def test_garbage_line_flagged_not_dropped():
    r = load()
    flagged = [i for i in r.items if i.flagged]
    assert len(flagged) == 1
    assert flagged[0].line_total == Decimal("3.33")


def test_flagged_excluded_from_total_check():
    r = load()
    subtotal = sum(i.line_total for i in r.items if not i.flagged and i.line_total is not None)
    assert subtotal + r.tax == r.total
