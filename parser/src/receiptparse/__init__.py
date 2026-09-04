from receiptparse.dialects import detect_dialect, register_dialect


def parse_receipt(text):
    return detect_dialect(text).parse(text)


__all__ = ["parse_receipt", "register_dialect"]