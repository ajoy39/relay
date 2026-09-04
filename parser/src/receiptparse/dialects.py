"""
Dialect handling for receipt parsing.

This module provides the dialect system for different receipt formats.
"""
from receiptparse.parser import parse_generic


class GenericDialect:
    """Generic dialect that matches everything and parses with parse_generic."""
    
    name = "generic"
    
    def matches(self, text):
        """Always matches."""
        return True
    
    def parse(self, text):
        """Parse using the generic parser."""
        return parse_generic(text)


class GiantDialect:
    """Giant dialect with structural matching rules."""
    
    name = "giant"
    
    def matches(self, text):
        """Match Giant receipts based on structural patterns."""
        lines = text.strip().split('\n')
        for line in lines:
            stripped = line.strip()
            # Check for lines starting with BALANCE after leading *, or containing PRICE YOU PAY
            if (stripped.startswith('*') and 'BALANCE' in stripped.lstrip('*').strip()) or \
               'PRICE YOU PAY' in stripped:
                return True
            # Check for item lines ending in amount followed by single capital letter (e.g. "4.19 F")
            if stripped.endswith((' A', ' B', ' C', ' D', ' E', ' F', ' G', ' H', ' I', ' J', ' K', ' L', ' M',
                                  ' N', ' O', ' P', ' Q', ' R', ' S', ' T', ' U', ' V', ' W', ' X', ' Y', ' Z')):
                # Check if the line ends with a price (decimal number) followed by a capital letter
                import re
                match = re.search(r'(\d+\.\d+)\s+([A-Z])$', stripped)
                if match:
                    return True
        return False
    
    def parse(self, text):
        """Parse using the generic parser."""
        return parse_generic(text)


_registered = []


def register_dialect(dialect):
    """Register a new dialect."""
    _registered.append(dialect)


def detect_dialect(text):
    """Detect which dialect applies to the receipt text."""
    # Check registered dialects first (newest first)
    for dialect in reversed(_registered):
        if dialect.matches(text):
            return dialect
    
    # Check built-in dialects
    giant = GiantDialect()
    if giant.matches(text):
        return giant
    
    # Default to generic
    generic = GenericDialect()
    return generic