#!/usr/bin/env python3

# Get the complete list of CCXT exchanges from README
import requests
import re
import json

url = "https://raw.githubusercontent.com/ccxt/ccxt/master/README.md"
response = requests.get(url)
content = response.text

# Extract exchange table entries - improved parsing
lines = content.split('\n')
exchanges = []

for line in lines:
    # Match table rows with exchange entries
    if '|' in line and not line.startswith('|') and not line.startswith('|---'):
        # Split by | and clean up
        parts = [p.strip() for p in line.split('|')[1:-1]]  # Remove first and last empty
        
        if len(parts) >= 3:
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
                not exchange_name.startswith('http') and
                not exchange_name.startswith('www')):
                
                exchanges.append(exchange_name.lower())

# Remove duplicates while preserving order
seen = set()
unique_exchanges = []
for exchange in exchanges:
    if exchange not in seen:
        seen.add(exchange)
        unique_exchanges.append(exchange)

print(f"Total CCXT exchanges found: {len(unique_exchanges)}")

# Current CCXT-Zig implementations
current_zig_exchanges = [
    'binance', 'kraken', 'coinbase', 'bybit', 'okx', 'gate', 'huobi',
    'kucoin', 'bitfinex', 'gemini', 'bitget', 'bitmex', 'deribit', 
    'mexc', 'bitstamp', 'poloniex', 'bitrue', 'phemex', 'bingx', 
    'xtcom', 'coinex', 'probit', 'woox', 'bitmart', 'ascendex',
    'hyperliquid', 'uniswap', 'pancakeswap', 'dydx',
    'htx', 'hitbtc', 'bitso', 'mercado', 'upbit'
]

print(f"Current CCXT-Zig exchanges: {len(current_zig_exchanges)}")

# Find missing exchanges
missing_exchanges = []
for exchange in unique_exchanges:
    if exchange not in current_zig_exchanges:
        missing_exchanges.append(exchange)

print(f"\nMissing exchanges ({len(missing_exchanges)}):")
for i, exchange in enumerate(sorted(missing_exchanges), 1):
    print(f"{i:2d}. {exchange}")

# Save to file
with open('ccxt_complete_analysis.json', 'w') as f:
    json.dump({
        'total_ccxt': unique_exchanges,
        'current_zig': current_zig_exchanges,
        'missing': sorted(missing_exchanges),
        'coverage_percentage': round(len(current_zig_exchanges) / len(unique_exchanges) * 100, 1)
    }, f, indent=2)

print(f"\nCurrent coverage: {len(current_zig_exchanges)}/{len(unique_exchanges)} = {len(current_zig_exchanges) / len(unique_exchanges) * 100:.1f}%")
print("Analysis saved to ccxt_complete_analysis.json")