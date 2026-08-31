"""Acceptance tests for ticket 0004 — department headers set category.

Read-only to the implementer. Contradiction → stop-and-report, never a test edit.
The 0001 suite and test_giant_lines.py stay green.
"""
from decimal import Decimal
from pathlib import Path

from receiptparse import parse_receipt

FIXTURES = Path(__file__).parent / "fixtures"


def load():
    return parse_receipt((FIXTURES / "giant_departments.txt").read_text())


def test_metadata():
    r = load()
    assert r.date == "2026-06-16"
    assert r.total == Decimal("32.69")
    assert r.total_matches is True


def test_headers_are_not_items():
    r = load()
    assert len(r.items) == 6
    names = {i.name for i in r.items}
    for header in ("dairy", "grocery", "deli", "frozen food", "misc"):
        assert header not in names


def test_pre_header_item_uses_name_rules():
    r = load()
    oj = next(i for i in r.items if i.name == "orange juice 64 oz")
    assert oj.category == "beverage"  # no header seen yet → 0001 name rules


def test_header_category_wins_inside_section():
    r = load()
    cat = {i.name: i.category for i in r.items}
    assert cat["whole milk 1 gallon"] == "dairy"          # DAIRY
    assert cat["sparkling water 12 pack"] == "pantry"     # GROCERY beats name-rule 'beverage'
    assert cat["boneless chicken breast"] == "meat"       # DELI maps to meat
    assert cat["frozen peas"] == "frozen"                 # FROZEN FOOD
    assert cat["cholula hot sce"] == "other"              # unknown header MISC
