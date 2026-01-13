# Field Mapper System Documentation

## Overview

The Field Mapper system provides centralized field name normalization and validation for CCXT-Zig exchanges. Different cryptocurrency exchanges use different naming conventions for the same data fields - the Field Mapper translates these exchange-specific names to internal standardized names, ensuring consistent data handling across all supported exchanges.

## Problem Statement

Different exchanges use different field names for the same data:
- **OKX/Hyperliquid**: `px`, `sz`, `bidPx`, `bidSz`, `askPx`, `askSz`
- **Binance**: `price`, `qty`, `bidPrice`, `bidQty`, `askPrice`, `askQty`
- **Bybit**: `lastPrice`, `size`, `bid1Price`, `bid1Size`, `ask1Price`, `ask1Size`
- **Kraken**: `c` (close), `v` (volume), `b` (bid), `a` (ask), and uses `XBT` instead of `BTC`

Without a centralized mapping system, each exchange implementation would need to manually handle these variations, leading to:
- Code duplication
- Inconsistent field handling
- Difficult maintenance
- Error-prone parsing

## Architecture

### Core Components

#### 1. **FieldMapping** (`src/utils/field_mapper.zig`)
Stores the mapping configuration for a specific exchange.

```zig
pub const FieldMapping = struct {
    allocator: std.mem.Allocator,
    exchange: []const u8,
    mappings: std.StringHashMap([]const []const u8),
    required_fields: std.StringHashMap([]const []const u8),
    
    pub fn addMapping(self: *FieldMapping, standard: []const u8, exchange_fields: []const []const u8) !void
    pub fn addRequiredFields(self: *FieldMapping, operation: OperationType, fields: []const []const u8) !void
    pub fn getExchangeFields(self: *FieldMapping, standard_field: []const u8) ?[]const []const u8
}
```

**Features:**
- Maps standard field names (e.g., "price") to exchange-specific variants (e.g., ["px", "lastPx", "price"])
- Supports multiple fallback options per field
- Defines required fields per operation type (ticker, trade, orderbook, etc.)

#### 2. **FieldMapperUtils**
Utility functions for using field mappings during parsing.

```zig
pub const FieldMapperUtils = struct {
    pub fn getFieldMapping(allocator: std.mem.Allocator, exchange_name: []const u8) !FieldMapping
    pub fn getField(parser: *json.JsonParser, json_val: std.json.Value, standard_field: []const u8, field_mapping: *const FieldMapping) ?std.json.Value
    pub fn getFloatField(...) f64
    pub fn getStringField(...) []const u8
    pub fn getIntField(...) i64
    pub fn validateFields(...) !ValidationResult
    pub fn validateOperation(...) !ValidationResult
}
```

**Key Methods:**
- `getFieldMapping()` - Returns the mapping for a specific exchange
- `getField()` - Retrieves a field value trying exchange-specific names first, then standard name
- `validateFields()` - Checks that required fields are present before parsing
- Type-specific getters (`getFloatField`, `getStringField`, `getIntField`) with automatic mapping

#### 3. **OperationType**
Enum defining different data operation types for validation.

```zig
pub const OperationType = enum {
    ticker,
    trade,
    orderbook,
    market,
    balance,
    order,
    ohlcv,
    position,
}
```

#### 4. **ValidationResult**
Contains validation results with details about missing fields.

```zig
pub const ValidationResult = struct {
    valid: bool,
    missing_fields: []const []const u8,
}
```

## Supported Exchanges

The field mapper currently supports:

1. **OKX** - Uses `px/sz` notation
2. **Bybit** - Uses `lastPrice`, `bid1Price`, `ask1Price` format
3. **Binance** - Standard `price`, `qty` format
4. **Kraken** - Single-letter abbreviations (`c`, `v`, `b`, `a`)
5. **Hyperliquid** - DEX with `px/sz` notation, `midPx`, `prevDayPx` fields
6. **Generic** - Fallback for unmapped exchanges

## Hyperliquid Implementation

Hyperliquid is a high-performance decentralized perpetuals exchange that uses unique field naming:

### Field Mappings
```zig
// Price fields
"price" → ["px", "price"]
"midPrice" → ["midPx", "mid"]
"markPrice" → ["markPx", "mark"]
"prevDayPrice" → ["prevDayPx"]

// Size fields  
"size" → ["sz", "size"]
"amount" → ["sz", "amount"]

// Volume fields
"volume" → ["dayNtlVlm", "volume"]
"openInterest" → ["openInterest", "oi"]
```

### API Endpoints

Hyperliquid uses a unified `/info` and `/exchange` endpoint structure:

**Public Data** (POST to `/info`):
- `{"type":"meta"}` - Get all perpetual markets
- `{"type":"allMids"}` - Get mid prices for all markets
- `{"type":"l2Book","coin":"BTC"}` - Get L2 orderbook
- `{"type":"tradeHistory","coin":"BTC"}` - Get recent trades
- `{"type":"candleSnapshot","req":{...}}` - Get OHLCV data

**Private Data** (POST to `/info`):
- `{"type":"clearinghouseState","user":"0x..."}` - Get account balance
- `{"type":"openOrders","user":"0x..."}` - Get open orders
- `{"type":"userFills","user":"0x..."}` - Get order fills/history

**Trading** (POST to `/exchange`):
- `{"type":"order","orders":[...]}` - Create orders
- `{"type":"cancel","cancels":[...]}` - Cancel orders

### Implementation

```zig
pub const Hyperliquid = struct {
    allocator: std.mem.Allocator,
    base: exchange.BaseExchange,
    field_mapping: field_mapper.FieldMapping,
    // ... other fields
    
    pub fn init(allocator: std.mem.Allocator, auth_config: auth.AuthConfig, testnet: bool) !*Hyperliquid {
        // Initialize field mapping
        self.field_mapping = try field_mapper.FieldMapperUtils.getFieldMapping(allocator, "hyperliquid");
        // ... rest of initialization
    }
    
    fn parseTrade(self: *Hyperliquid, json_val: std.json.Value, symbol: []const u8) !Trade {
        const parser = &self.base.json_parser;
        const mapper = &self.field_mapping;
        
        // Use field mapper for consistent field extraction
        const price = field_mapper.FieldMapperUtils.getFloatField(parser, json_val, "price", mapper, 0);
        const size = field_mapper.FieldMapperUtils.getFloatField(parser, json_val, "size", mapper, 0);
        const timestamp = field_mapper.FieldMapperUtils.getIntField(parser, json_val, "timestamp", mapper, time.TimeUtils.now());
        
        // ... rest of parsing
    }
}
```

## Usage Examples

### 1. Initialize Field Mapping

```zig
const allocator = std.heap.page_allocator;
var mapping = try field_mapper.FieldMapperUtils.getFieldMapping(allocator, "okx");
defer mapping.deinit();
```

### 2. Parse Fields with Mapping

```zig
const parser = &json_parser;
const json_str = 
    \\{"px": 50000, "sz": 1.5, "ts": 1234567890}
;

var parsed = try parser.parse(json_str);
defer parsed.deinit();

// Extract fields using mapping - automatically tries "px" for OKX
const price = field_mapper.FieldMapperUtils.getFloatField(
    parser,
    parsed.value,
    "price",  // standard field name
    &mapping,
    0
);
// Returns 50000 (found via "px" mapping)

const size = field_mapper.FieldMapperUtils.getFloatField(
    parser,
    parsed.value,
    "size",   // standard field name
    &mapping,
    0
);
// Returns 1.5 (found via "sz" mapping)
```

### 3. Validate Required Fields

```zig
const required = [_][]const u8{ "price", "size", "timestamp" };
const result = try field_mapper.FieldMapperUtils.validateFields(
    allocator,
    parsed.value,
    &required,
    &mapping,
);
defer result.deinit(allocator);

if (!result.valid) {
    std.debug.print("Missing fields: ", .{});
    for (result.missing_fields) |field| {
        std.debug.print("{s} ", .{field});
    }
    return error.MissingRequiredFields;
}
```

### 4. Operation-Level Validation

```zig
const result = try field_mapper.FieldMapperUtils.validateOperation(
    allocator,
    parsed.value,
    .ticker,  // OperationType
    &mapping,
);
defer result.deinit(allocator);

if (!result.valid) {
    return error.InvalidTicker;
}
```

## Adding New Exchange Mappings

To add a new exchange to the field mapper:

### 1. Add Exchange-Specific Mapping Function

```zig
fn createNewExchangeMapping(allocator: std.mem.Allocator) !FieldMapping {
    var mapping = try FieldMapping.init(allocator, "newexchange");
    
    // Price fields
    try mapping.addMapping("price", &[_][]const u8{ "last_price", "price" });
    try mapping.addMapping("bidPrice", &[_][]const u8{ "bid", "bidPrice" });
    try mapping.addMapping("askPrice", &[_][]const u8{ "ask", "askPrice" });
    
    // Size fields
    try mapping.addMapping("size", &[_][]const u8{ "quantity", "size" });
    try mapping.addMapping("amount", &[_][]const u8{ "qty", "amount" });
    
    // Volume fields
    try mapping.addMapping("volume", &[_][]const u8{ "vol", "volume" });
    
    // Timestamp
    try mapping.addMapping("timestamp", &[_][]const u8{ "time", "timestamp" });
    
    // Required fields per operation
    try mapping.addRequiredFields(.ticker, &[_][]const u8{ "price" });
    try mapping.addRequiredFields(.trade, &[_][]const u8{ "price", "size", "timestamp" });
    try mapping.addRequiredFields(.orderbook, &[_][]const u8{ "bids", "asks" });
    
    return mapping;
}
```

### 2. Register in `getFieldMapping()`

```zig
pub fn getFieldMapping(allocator: std.mem.Allocator, exchange_name: []const u8) !FieldMapping {
    if (std.mem.eql(u8, exchange_name, "okx")) {
        return try createOkxMapping(allocator);
    } else if (std.mem.eql(u8, exchange_name, "newexchange")) {
        return try createNewExchangeMapping(allocator);
    } 
    // ... other exchanges
    else {
        return try createGenericMapping(allocator);
    }
}
```

### 3. Use in Exchange Implementation

```zig
pub const NewExchange = struct {
    field_mapping: field_mapper.FieldMapping,
    
    pub fn init(allocator: std.mem.Allocator, ...) !*NewExchange {
        self.field_mapping = try field_mapper.FieldMapperUtils.getFieldMapping(allocator, "newexchange");
        // ...
    }
    
    pub fn deinit(self: *NewExchange) void {
        self.field_mapping.deinit();
        // ...
    }
}
```

## Best Practices

### 1. Always Validate Before Parsing
```zig
// Validate first
const result = try field_mapper.FieldMapperUtils.validateOperation(
    allocator,
    json_val,
    .trade,
    &mapper,
);
defer result.deinit(allocator);

if (!result.valid) {
    std.log.err("Missing required fields for trade: {any}", .{result.missing_fields});
    return error.InvalidTradeData;
}

// Then parse
const trade = try self.parseTrade(json_val, symbol);
```

### 2. Use Field Mapper for All Exchanges
Even exchanges with "standard" field names should use the field mapper for consistency and future-proofing.

### 3. Provide Fallback Field Names
Order field names from most-specific to least-specific:
```zig
try mapping.addMapping("price", &[_][]const u8{ "lastPx", "last", "price" });
```

### 4. Document Exchange-Specific Quirks
```zig
/// Kraken field mapping
/// Note: Kraken uses single-letter field names and XBT instead of BTC
fn createKrakenMapping(allocator: std.mem.Allocator) !FieldMapping {
    // ...
}
```

## Error Handling

The field mapper provides detailed error information:

```zig
const result = try field_mapper.FieldMapperUtils.validateFields(
    allocator,
    json_val,
    required_fields,
    &mapping,
);

if (!result.valid) {
    std.log.err(
        "Exchange: {s}, Operation: {s}, Missing fields: {any}",
        .{
            mapping.exchange,
            "ticker",
            result.missing_fields,
        }
    );
    return error.MissingRequiredFields;
}
```

## Testing

The field mapper includes comprehensive unit tests:

```bash
zig test src/utils/field_mapper.zig
```

Tests cover:
- Field mapping retrieval
- Field value extraction with fallbacks
- Required field validation
- Missing field detection
- Multiple exchange configurations

## Performance Considerations

1. **Field Mapping Initialization**: Field mappings are initialized once per exchange instance and reused
2. **Lookup Efficiency**: HashMap-based lookups provide O(1) average-case performance
3. **Memory**: Field mappings are lightweight, using shared string slices where possible
4. **Caching**: Field mappings are stored in the exchange struct to avoid repeated initialization

## Future Enhancements

Potential improvements to the field mapper system:

1. **Dynamic Mapping Configuration**: Load mappings from JSON configuration files
2. **Mapping Validation**: Validate that all required standard fields have mappings
3. **Performance Metrics**: Track field mapping hit/miss rates
4. **Auto-Discovery**: Detect field names automatically from API responses
5. **Type Conversion**: Automatic type conversion based on field semantics
6. **Localization**: Support for multi-language field names

## Related Files

- `/src/utils/field_mapper.zig` - Core field mapper implementation
- `/src/exchanges/hyperliquid.zig` - Complete Hyperliquid implementation using field mapper
- `/src/exchanges/okx.zig` - OKX implementation (manual field handling - can be migrated)
- `/src/utils/json.zig` - JSON parsing utilities used by field mapper

## Conclusion

The Field Mapper system provides a robust, maintainable solution for normalizing exchange-specific field names across CCXT-Zig. By centralizing field mappings and validation logic, it reduces code duplication, improves consistency, and simplifies the implementation of new exchanges.
