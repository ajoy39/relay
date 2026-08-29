"""Acceptance tests for ticket 0001 — the contract, executable.

Read-only to the implementer. Every expected value below is stated in the ticket's
specification; if a test seems to contradict the ticket, that's a stop-and-report,
not a test edit.
"""
import csv
import io
import os
import subprocess
import sys
from decimal import Decimal
from pathlib import Path

import pytest

from receiptparse import parse_receipt

FIXTURES = Path(__file__).parent / "fixtures"


def load(name: str):
    return parse_receipt((FIXTURES / name).read_text())


# ---------------------------------------------------------------- basic.txt

def test_basic_metadata():
    r = load("basic.txt")
    assert r.date == "2026-08-12"
    assert r.tax == Decimal("0.55")
    assert r.total == Decimal("11.67")
    assert r.total_matches is True


def test_basic_items_normalized():
    r = load("basic.txt")
    got = [(i.name, i.category, i.qty, i.line_total, i.flagged) for i in r.items]
    assert got == [
        ("whole milk 1 gallon", "dairy", 1, Decimal("3.49"), False),
        ("wheat bread", "bakery", 1, Decimal("2.29"), False),
        ("large eggs dozen", "dairy", 1, Decimal("4.19"), False),
        ("bananas", "produce", 1, Decimal("1.15"), False),
    ]


def test_basic_raw_preserved():
    r = load("basic.txt")
    assert r.items[0].raw.startswith("WHL MLK 1GAL")


# ------------------------------------------------- multibuy_discount.txt

def test_multibuy_qty_and_line_total():
    r = load("multibuy_discount.txt")
    yogurt = r.items[0]
    assert yogurt.name == "greek yogurt"
    assert yogurt.category == "dairy"
    assert yogurt.qty == 2
    assert yogurt.line_total == Decimal("2.58")


def test_discount_line_is_signed_discount_category():
    r = load("multibuy_discount.txt")
    coupon = next(i for i in r.items if i.line_total == Decimal("-1.50"))
    assert coupon.category == "discount"
    assert coupon.name == "coupon coffee"
    assert coupon.flagged is False


def test_multibuy_receipt_totals():
    r = load("multibuy_discount.txt")
    assert r.total == Decimal("14.48")
    assert r.total_matches is True
    names = {i.name for i in r.items}
    assert "coffee ground" in names          # token order preserved
    assert "sparkling water 12 pack" in names


# --------------------------------------------------------- mismatch.txt

def test_total_mismatch_detected():
    r = load("mismatch.txt")
    assert r.total_matches is False
    assert r.total == Decimal("6.18")


def test_mismatch_categories():
    r = load("mismatch.txt")
    got = {i.name: i.category for i in r.items}
    assert got == {"orange juice 64 oz": "beverage", "frozen peas": "frozen"}


# ----------------------------------------------------------- gnarly.txt

def test_gnarly_normalization_and_brand_drop():
    r = load("gnarly.txt")
    names = [i.name for i in r.items if not i.flagged]
    assert names == [
        "whole milk 2%",              # GV dropped, WHL MLK expanded, 2% passes through
        "boneless chicken breast",
        "roasted garlic hummus",
        "paper towels 6 roll",
    ]
    cats = [i.category for i in r.items if not i.flagged]
    assert cats == ["dairy", "meat", "pantry", "household"]


def test_garbage_line_flagged_never_dropped():
    r = load("gnarly.txt")
    flagged = [i for i in r.items if i.flagged]
    assert len(flagged) == 1
    assert flagged[0].category == "other"
    assert flagged[0].line_total == Decimal("9.99")
    assert "##~~%%@@!!" in flagged[0].raw


def test_flagged_excluded_from_total_check():
    # 21.49 (real items) + 0.73 tax == 22.22 only if the flagged 9.99 is excluded
    r = load("gnarly.txt")
    assert r.total_matches is True


# ---------------------------------------------------------- no_date.txt

def test_missing_date_is_none_and_money_still_decimal():
    r = load("no_date.txt")
    assert r.date is None
    assert r.total_matches is True
    for i in r.items:
        assert isinstance(i.line_total, Decimal)   # floats in money paths are defects


# ----------------------------------------------------------------- CLI

def run_cli(*args):
    env = dict(os.environ)
    src = str(Path(__file__).parent.parent / "src")
    env["PYTHONPATH"] = src + os.pathsep + env.get("PYTHONPATH", "")
    return subprocess.run(
        [sys.executable, "-m", "receiptparse", *args],
        capture_output=True, text=True, env=env,
    )


def test_cli_csv_shape_and_values():
    p = run_cli(str(FIXTURES / "basic.txt"), str(FIXTURES / "no_date.txt"))
    assert p.returncode == 0, p.stderr
    rows = list(csv.reader(io.StringIO(p.stdout)))
    assert rows[0] == ["date", "raw", "name", "category", "qty", "line_total", "flagged"]
    assert len(rows) == 1 + 4 + 2                      # header + basic items + no_date items
    assert rows[1][0] == "2026-08-12"
    assert rows[1][2] == "whole milk 1 gallon"
    assert rows[5][0] == ""                            # missing date -> empty field
    assert rows[5][6] in ("false", "False") and rows[1][6] in ("false", "False")


def test_cli_missing_file_exits_2():
    p = run_cli(str(FIXTURES / "does_not_exist.txt"))
    assert p.returncode == 2
    assert p.stderr.strip() != ""
