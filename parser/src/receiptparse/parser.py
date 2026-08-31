"""
Receipt parser for grocery receipts.

This module provides a parser for grocery receipt text that converts it into
structured line items with normalized names and categories.
"""
from __future__ import annotations

import re
from dataclasses import dataclass
from decimal import Decimal
from typing import List

# Alias table for name normalization
ALIAS_TABLE = {
    "WHL MLK": "whole milk",
    "GRND": "ground",
    "1GAL": "1 gallon",
    "CPN": "coupon",
    "LG": "large",
    "SPARK": "sparkling",
    "DZ": "dozen",
    "12PK": "12 pack",
    "GRK": "greek",
    "OJ": "orange juice",
    "64OZ": "64 oz",
    "GV": "",  # Drop this token
    "BNLS": "boneless",
    "CHKN": "chicken",
    "BRST": "breast",
    "RSTD": "roasted",
    "GRLC": "garlic",
    "HMMS": "hummus",
    "PPR": "paper",
    "TWLS": "towels",
    "FRZ": "frozen",
    "6RL": "6 roll",
}

@dataclass
class Item:
    raw: str
    name: str
    category: str
    qty: int
    line_total: Decimal | None
    flagged: bool

@dataclass
class Receipt:
    date: str | None
    tax: Decimal
    total: Decimal | None
    total_matches: bool
    items: List[Item]

def parse_receipt(text: str) -> Receipt:
    """
    Parse receipt text into structured data.
    
    Args:
        text: Receipt text (from OCR)
        
    Returns:
        Parsed receipt with items, date, tax, total
    """
    lines = text.strip().split('\n')
    
    # Initialize variables
    date = None
    tax = Decimal("0")
    total = None
    items = []
    
    # Process lines
    for line in lines:
        line = line.strip()
        if not line:
            continue
            
        # Handle date line (look for date pattern in header lines)
        # First try 4-digit year pattern, then 2-digit year pattern
        date_match = re.search(r'(\d{2}/\d{2}/\d{4})', line)
        if not date_match:
            date_match = re.search(r'(\d{2}/\d{2}/\d{2})', line)
        
        if date_match and not date:
            date_str = date_match.group(1)
            if len(date_str.split('/')[-1]) == 4:
                # 4-digit year format MM/DD/YYYY
                date_parts = date_str.split('/')
                date = f"{date_parts[2]}-{date_parts[0]}-{date_parts[1]}"
            else:
                # 2-digit year format MM/DD/YY -> convert to 20YY-MM-DD
                date_parts = date_str.split('/')
                year = int(date_parts[2])
                full_year = 2000 + year if year < 50 else 1900 + year  # Assume 2000+ for 00-49, 1900+ for 50-99
                date = f"{full_year:04d}-{date_parts[0]}-{date_parts[1]}"
            continue
            
        # Handle tax line
        if line.startswith("TAX"):
            tax_match = re.search(r'TAX\s+([0-9.]+)', line)
            if tax_match:
                tax = Decimal(tax_match.group(1))
            continue
            
        # Handle total line (including BALANCE lines)
        if line.startswith("TOTAL") or (line.startswith("*") and "BALANCE" in line.lstrip("*").strip()):
            total_match = re.search(r'(?:TOTAL|BALANCE)\s+([0-9.]+)', line)
            if total_match:
                total = Decimal(total_match.group(1))
            continue
            
        # Handle summary lines (ignore lines with "PRICE YOU PAY")
        if "PRICE YOU PAY" in line:
            continue
            
        # Parse item lines with new Giant dialect constructs
        item = parse_item_line(line)
        if item:
            items.append(item)
    
    # Check if total matches
    subtotal = Decimal("0")
    for item in items:
        if not item.flagged and item.line_total is not None:
            subtotal += item.line_total
    
    if total is not None:
        total_matches = abs(subtotal + tax - total) <= Decimal("0.01")
    else:
        total_matches = False
    
    return Receipt(
        date=date,
        tax=tax,
        total=total,
        total_matches=total_matches,
        items=items
    )

def parse_item_line(line: str) -> Item | None:
    """
    Parse a single item line into an Item object, handling Giant dialect constructs.
    
    Args:
        line: Line from receipt text
        
    Returns:
        Item object or None if parsing fails
    """
    line = line.strip()
    
    # Check for trailing minus discount (like "1.20-F")
    # This pattern matches a number followed by a dash and a letter
    trailing_minus_match = re.search(r'(-?\d+\.\d+)-([A-Z])$', line)
    if trailing_minus_match:
        amount_str = trailing_minus_match.group(1)
        # For trailing minus, we make the amount negative
        amount = Decimal(amount_str) * Decimal("-1")
        # Remove the amount and suffix from the line for name processing
        name_line = line[:trailing_minus_match.start()].strip()
        tokens = name_line.split()
        name_tokens = tokens
        suffix = trailing_minus_match.group(2)
    else:
        # Check for flag letter suffix (like "4.19 F")
        flag_letter_match = re.search(r'(-?\d+\.\d+)\s+([A-Z])$', line)
        if flag_letter_match:
            amount_str = flag_letter_match.group(1)
            amount = Decimal(amount_str)
            # Remove the amount and suffix from the line for name processing
            name_line = line[:flag_letter_match.start()].strip()
            tokens = name_line.split()
            name_tokens = tokens
            suffix = flag_letter_match.group(2)
        else:
            # Standard case: look for lines that end with a price
            # Match lines that end with a decimal number (including negative)
            amount_match = re.search(r'\s+(-?\d+\.\d+)$', line)
            if not amount_match:
                return None
                
            amount_str = amount_match.group(1)
            amount = Decimal(amount_str)
            # Remove the amount from tokens for name processing
            name_line = line[:-len(amount_str) - 1].strip()
            tokens = name_line.split()
            name_tokens = tokens
            suffix = None
    
    # Check if it's a multi-buy (e.g., "2 @ 1.29")
    qty = 1
    if len(name_tokens) >= 3 and name_tokens[-2] == "@":
        try:
            qty = int(name_tokens[-3])
            # Remove the qty tokens from name for normalization
            name_tokens = name_tokens[:-3]
        except Exception:
            pass  # Keep default quantity if parsing fails
            
    # Process the name part
    name = " ".join(name_tokens)
    normalized_name = normalize_name(name)
    
    # Determine category
    category = get_category(normalized_name, amount)
    
    # Check if the item has no ASCII letters (garbage)
    has_ascii_letters = any(c.isalpha() for c in name)
    if not has_ascii_letters:
        return Item(
            raw=line,
            name=name.lower(),
            category="other",
            qty=qty,
            line_total=amount,
            flagged=True
        )
    
    # Special handling for trailing minus discounts - they are not flagged
    flagged = False if suffix and suffix == "-" else not has_ascii_letters
    
    return Item(
        raw=line,
        name=normalized_name,
        category=category,
        qty=qty,
        line_total=amount,
        flagged=flagged
    )

def normalize_name(name: str) -> str:
    """
    Normalize a name using the alias table.
    
    Args:
        name: Raw name from receipt
        
    Returns:
        Normalized name
    """
    tokens = name.split()
    normalized_tokens = []
    i = 0
    
    # Try to match multi-word aliases first
    while i < len(tokens):
        # Check for multi-word matches (up to 3 words for safety)
        matched = False
        for length in range(min(3, len(tokens) - i), 0, -1):
            phrase = " ".join(tokens[i:i + length])
            if phrase in ALIAS_TABLE:
                replacement = ALIAS_TABLE[phrase]
                if replacement:  # Empty string means drop the token
                    normalized_tokens.append(replacement)
                matched = True
                i += length
                break
        
        if not matched:
            # Single token processing
            token = tokens[i]
            if token in ALIAS_TABLE:
                replacement = ALIAS_TABLE[token]
                if replacement:  # Empty string means drop the token
                    normalized_tokens.append(replacement)
            else:
                # Unknown tokens pass through lowercased
                normalized_tokens.append(token.lower())
            i += 1
    
    return " ".join(normalized_tokens)

def get_category(name: str, amount: Decimal) -> str:
    """
    Determine the category for an item based on its normalized name and amount.
    
    Args:
        name: Normalized name
        amount: Amount (negative for discounts)
        
    Returns:
        Category string
    """
    # If amount is negative, it's a discount
    if amount < 0:
        return "discount"
    
    # Check categories in order
    if "frozen" in name or "frz" in name:
        return "frozen"
    elif any(word in name for word in ["milk", "yogurt", "eggs"]):
        return "dairy"
    elif "chicken" in name:
        return "meat"
    elif "bread" in name:
        return "bakery"
    elif any(word in name for word in ["coffee", "water", "juice", "soda"]):
        return "beverage"
    elif any(word in name for word in ["paper", "towels"]):
        return "household"
    elif any(word in name for word in ["bananas", "apples"]):
        return "produce"
    elif "hummus" in name:
        return "pantry"
    else:
        return "other"