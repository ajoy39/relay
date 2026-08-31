from receiptparse.parser import parse_receipt
import sys
import os
import csv

def main():
    if len(sys.argv) < 2:
        print("Usage: python -m receiptparse FILE [FILE...]", file=sys.stderr)
        sys.exit(2)
        
    # Write CSV header
    writer = csv.writer(sys.stdout)
    writer.writerow(["date", "raw", "name", "category", "qty", "line_total", "flagged"])
    
    # Process each file
    for filepath in sys.argv[1:]:
        if not os.path.exists(filepath):
            print(f"receiptparse: {filepath}: No such file", file=sys.stderr)
            sys.exit(2)
            
        with open(filepath, 'r') as f:
            text = f.read()
            receipt = parse_receipt(text)
            
            for item in receipt.items:
                writer.writerow([
                    receipt.date or "",
                    item.raw,
                    item.name,
                    item.category,
                    item.qty,
                    str(item.line_total) if item.line_total is not None else "",
                    str(item.flagged).lower()
                ])

if __name__ == "__main__":
    main()