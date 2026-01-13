#!/usr/bin/env python3
import requests
import re
import json

# Fetch CCXT README
url = "https://raw.githubusercontent.com/ccxt/ccxt/master/README.md"
response = requests.get(url)
content = response.text

# Extract exchange table entries
lines = content.split('\n')
exchanges = []

for line in lines:
    # Match table rows with exchange entries
    if '|' in line and not line.startswith('|') and not line.startswith('|---'):
        # Split by | and clean up
        parts = [p.strip() for p in line.split('|')[1:-1]]  # Remove first and last empty
        
        if len(parts) >= 4:
            # Extract exchange name (usually in 2nd column)
            exchange_name = parts[1].strip()
            # Remove markdown links and images
            exchange_name = re.sub(r'\[([^\]]+)\]\([^\)]+\)', r'\1', exchange_name)
            exchange_name = re.sub(r'!\[([^\]]*)\]\([^\)]*\)', r'', exchange_name)
            exchange_name = exchange_name.strip()
            
            # Skip headers, images, etc.
            if (exchange_name and 
                not exchange_name.startswith('[') and
                not exchange_name.startswith('![') and
                not exchange_name.lower().startswith('exchange') and
                not exchange_name.lower().startswith('name') and
                exchange_name != '' and
                len(exchange_name) < 50 and  # Reasonable name length
                not exchange_name.startswith('http')):
                
                exchanges.append(exchange_name)

# Remove duplicates while preserving order
seen = set()
unique_exchanges = []
for exchange in exchanges:
    if exchange.lower() not in seen:
        seen.add(exchange.lower())
        unique_exchanges.append(exchange)

# Print results
print(f"Found {len(unique_exchanges)} exchanges from CCXT:")
print("=" * 50)
for i, exchange in enumerate(sorted(unique_exchanges), 1):
    print(f"{i:2d}. {exchange}")

# Save to file for analysis
with open('ccxt_exchanges.json', 'w') as f:
    json.dump(sorted(unique_exchanges), f, indent=2)

print(f"\nSaved to ccxt_exchanges.json")