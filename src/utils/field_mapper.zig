const std = @import("std");
const json = @import("json.zig");

/// Field mapping configuration for normalizing exchange-specific field names
/// to standardized internal field names used across the CCXT-Zig library.
///
/// # Purpose
/// Different exchanges use different naming conventions for the same fields:
/// - OKX uses "px" and "sz" for price and size
/// - Binance uses "price" and "qty"
/// - Hyperliquid uses "px" and "sz" similar to OKX
/// - Kraken uses "XBT" instead of "BTC" for Bitcoin
///
/// This module provides a centralized mapping system to normalize these variations
/// and validate that required fields are present before parsing.
///
/// # Example Usage
/// ```zig
/// const mapper = try FieldMapperUtils.getFieldMapping(allocator, "okx");
/// const price = try FieldMapperUtils.getField(json_val, "price", mapper);
/// try FieldMapperUtils.validateFields(json_val, &[_][]const u8{"price", "size"}, mapper);
/// ```

/// Operation types for field validation
pub const OperationType = enum {
    ticker,
    trade,
    orderbook,
    market,
    balance,
    order,
    ohlcv,
    position,
    
    pub fn toString(self: OperationType) []const u8 {
        return switch (self) {
            .ticker => "ticker",
            .trade => "trade",
            .orderbook => "orderbook",
            .market => "market",
            .balance => "balance",
            .order => "order",
            .ohlcv => "ohlcv",
            .position => "position",
        };
    }
};

/// Field mapping entry with primary and optional fallback field names
pub const FieldMap = struct {
    /// Standard field name used internally
    standard: []const u8,
    /// Exchange-specific field names (first one is primary)
    exchange_fields: []const []const u8,
};

/// Field mapping configuration for a specific exchange
pub const FieldMapping = struct {
    allocator: std.mem.Allocator,
    exchange: []const u8,
    /// Maps standard field names to exchange-specific field names
    mappings: std.StringHashMap([]const []const u8),
    /// Required fields per operation type
    required_fields: std.StringHashMap([]const []const u8),
    
    pub fn init(allocator: std.mem.Allocator, exchange: []const u8) !FieldMapping {
        return FieldMapping{
            .allocator = allocator,
            .exchange = exchange,
            .mappings = std.StringHashMap([]const []const u8).init(allocator),
            .required_fields = std.StringHashMap([]const []const u8).init(allocator),
        };
    }
    
    pub fn deinit(self: *FieldMapping) void {
        var mapping_iter = self.mappings.iterator();
        while (mapping_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.mappings.deinit();
        
        var required_iter = self.required_fields.iterator();
        while (required_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.required_fields.deinit();
        
        self.allocator.free(self.exchange);
    }
    
    /// Add a field mapping (standard -> exchange-specific names)
    pub fn addMapping(self: *FieldMapping, standard: []const u8, exchange_fields: []const []const u8) !void {
        const key = try self.allocator.dupe(u8, standard);
        const value = try self.allocator.dupe([]const u8, exchange_fields);
        try self.mappings.put(key, value);
    }
    
    /// Add required fields for an operation type
    pub fn addRequiredFields(self: *FieldMapping, operation: OperationType, fields: []const []const u8) !void {
        const key = try self.allocator.dupe(u8, operation.toString());
        const value = try self.allocator.dupe([]const u8, fields);
        try self.required_fields.put(key, value);
    }
    
    /// Get exchange-specific field names for a standard field
    pub fn getExchangeFields(self: *FieldMapping, standard_field: []const u8) ?[]const []const u8 {
        return self.mappings.get(standard_field);
    }
    
    /// Get required fields for an operation type
    pub fn getRequiredFieldsForOperation(self: *FieldMapping, operation: OperationType) ?[]const []const u8 {
        return self.required_fields.get(operation.toString());
    }
};

/// Validation result with details about missing fields
pub const ValidationResult = struct {
    valid: bool,
    missing_fields: []const []const u8,
    
    pub fn deinit(self: ValidationResult, allocator: std.mem.Allocator) void {
        for (self.missing_fields) |field| {
            allocator.free(field);
        }
        allocator.free(self.missing_fields);
    }
};

/// Field mapper utilities for parsing and validating exchange data
pub const FieldMapperUtils = struct {
    /// Get field mapping configuration for a specific exchange
    pub fn getFieldMapping(allocator: std.mem.Allocator, exchange_name: []const u8) !FieldMapping {
        if (std.mem.eql(u8, exchange_name, "okx")) {
            return try createOkxMapping(allocator);
        } else if (std.mem.eql(u8, exchange_name, "bybit")) {
            return try createBybitMapping(allocator);
        } else if (std.mem.eql(u8, exchange_name, "binance")) {
            return try createBinanceMapping(allocator);
        } else if (std.mem.eql(u8, exchange_name, "kraken")) {
            return try createKrakenMapping(allocator);
        } else if (std.mem.eql(u8, exchange_name, "hyperliquid")) {
            return try createHyperliquidMapping(allocator);
        } else {
            // Default/generic mapping
            return try createGenericMapping(allocator);
        }
    }
    
    /// Get a field value from JSON using field mapping with fallback
    /// Tries exchange-specific field names first, then falls back to standard name
    pub fn getField(
        _: *json.JsonParser,
        json_val: std.json.Value,
        standard_field: []const u8,
        field_mapping: *const FieldMapping,
    ) ?std.json.Value {
        // Try exchange-specific field names first
        if (field_mapping.getExchangeFields(standard_field)) |exchange_fields| {
            for (exchange_fields) |field_name| {
                if (json_val.object.get(field_name)) |value| {
                    return value;
                }
            }
        }
        
        // Fallback to standard field name
        return json_val.object.get(standard_field);
    }
    
    /// Get string field value with mapping
    pub fn getStringField(
        parser: *json.JsonParser,
        json_val: std.json.Value,
        standard_field: []const u8,
        field_mapping: *const FieldMapping,
        default: []const u8,
    ) []const u8 {
        const value = getField(parser, json_val, standard_field, field_mapping) orelse 
            return default;
        return parser.getStringValue(value, default);
    }
    
    /// Get float field value with mapping
    pub fn getFloatField(
        parser: *json.JsonParser,
        json_val: std.json.Value,
        standard_field: []const u8,
        field_mapping: *const FieldMapping,
        default: f64,
    ) f64 {
        const value = getField(parser, json_val, standard_field, field_mapping) orelse 
            return default;
        return parser.getFloat(value, default);
    }
    
    /// Get integer field value with mapping
    pub fn getIntField(
        parser: *json.JsonParser,
        json_val: std.json.Value,
        standard_field: []const u8,
        field_mapping: *const FieldMapping,
        default: i64,
    ) i64 {
        const value = getField(parser, json_val, standard_field, field_mapping) orelse 
            return default;
        return parser.getInt(value, default);
    }
    
    /// Validate that required fields are present in JSON
    pub fn validateFields(
        allocator: std.mem.Allocator,
        json_val: std.json.Value,
        required_fields: []const []const u8,
        field_mapping: *const FieldMapping,
    ) !ValidationResult {
        if (json_val != .object) {
            return ValidationResult{
                .valid = false,
                .missing_fields = try allocator.dupe([]const u8, required_fields),
            };
        }
        
        var missing = std.ArrayList([]const u8).init(allocator);
        defer missing.deinit();
        
        for (required_fields) |standard_field| {
            var found = false;
            
            // Check exchange-specific field names
            if (field_mapping.getExchangeFields(standard_field)) |exchange_fields| {
                for (exchange_fields) |field_name| {
                    if (json_val.object.contains(field_name)) {
                        found = true;
                        break;
                    }
                }
            }
            
            // Check standard field name
            if (!found and json_val.object.contains(standard_field)) {
                found = true;
            }
            
            if (!found) {
                try missing.append(try allocator.dupe(u8, standard_field));
            }
        }
        
        return ValidationResult{
            .valid = missing.items.len == 0,
            .missing_fields = try missing.toOwnedSlice(),
        };
    }
    
    /// Validate fields for a specific operation type
    pub fn validateOperation(
        allocator: std.mem.Allocator,
        json_val: std.json.Value,
        operation: OperationType,
        field_mapping: *const FieldMapping,
    ) !ValidationResult {
        const required = field_mapping.getRequiredFieldsForOperation(operation) orelse 
            return ValidationResult{ .valid = true, .missing_fields = &[_][]const u8{} };
        
        return try validateFields(allocator, json_val, required, field_mapping);
    }
};

// ==================== Exchange-Specific Mappings ====================

/// OKX field mapping (uses px/sz notation)
fn createOkxMapping(allocator: std.mem.Allocator) !FieldMapping {
    var mapping = try FieldMapping.init(allocator, "okx");
    
    // Price fields
    try mapping.addMapping("price", &[_][]const u8{ "px", "lastPx", "price" });
    try mapping.addMapping("bidPrice", &[_][]const u8{ "bidPx", "bidPrice" });
    try mapping.addMapping("askPrice", &[_][]const u8{ "askPx", "askPrice" });
    try mapping.addMapping("openPrice", &[_][]const u8{ "openPx", "open" });
    try mapping.addMapping("highPrice", &[_][]const u8{ "highPx", "high24h", "high" });
    try mapping.addMapping("lowPrice", &[_][]const u8{ "lowPx", "low24h", "low" });
    try mapping.addMapping("closePrice", &[_][]const u8{ "closePx", "close" });
    
    // Size/Amount fields
    try mapping.addMapping("size", &[_][]const u8{ "sz", "size", "amount" });
    try mapping.addMapping("bidSize", &[_][]const u8{ "bidSz", "bidSize" });
    try mapping.addMapping("askSize", &[_][]const u8{ "askSz", "askSize" });
    try mapping.addMapping("amount", &[_][]const u8{ "sz", "amt", "amount" });
    
    // Volume fields
    try mapping.addMapping("volume", &[_][]const u8{ "vol24h", "vol", "volume" });
    try mapping.addMapping("quoteVolume", &[_][]const u8{ "volCcy24h", "quoteVol", "quoteVolume" });
    try mapping.addMapping("baseVolume", &[_][]const u8{ "vol24h", "baseVol", "baseVolume" });
    
    // Timestamp
    try mapping.addMapping("timestamp", &[_][]const u8{ "ts", "timestamp", "time" });
    
    // Required fields per operation
    try mapping.addRequiredFields(.ticker, &[_][]const u8{ "price" });
    try mapping.addRequiredFields(.trade, &[_][]const u8{ "price", "size", "timestamp" });
    try mapping.addRequiredFields(.orderbook, &[_][]const u8{ "bids", "asks" });
    try mapping.addRequiredFields(.order, &[_][]const u8{ "orderId", "price", "size" });
    
    return mapping;
}

/// Bybit field mapping
fn createBybitMapping(allocator: std.mem.Allocator) !FieldMapping {
    var mapping = try FieldMapping.init(allocator, "bybit");
    
    // Price fields
    try mapping.addMapping("price", &[_][]const u8{ "price", "lastPrice", "last" });
    try mapping.addMapping("bidPrice", &[_][]const u8{ "bid1Price", "bidPrice", "bid" });
    try mapping.addMapping("askPrice", &[_][]const u8{ "ask1Price", "askPrice", "ask" });
    try mapping.addMapping("highPrice", &[_][]const u8{ "highPrice24h", "high" });
    try mapping.addMapping("lowPrice", &[_][]const u8{ "lowPrice24h", "low" });
    try mapping.addMapping("openPrice", &[_][]const u8{ "prevPrice24h", "open" });
    
    // Size fields
    try mapping.addMapping("size", &[_][]const u8{ "size", "qty", "amount" });
    try mapping.addMapping("bidSize", &[_][]const u8{ "bid1Size", "bidQty" });
    try mapping.addMapping("askSize", &[_][]const u8{ "ask1Size", "askQty" });
    try mapping.addMapping("amount", &[_][]const u8{ "qty", "size", "amount" });
    
    // Volume fields
    try mapping.addMapping("volume", &[_][]const u8{ "volume24h", "turnover24h", "volume" });
    try mapping.addMapping("quoteVolume", &[_][]const u8{ "turnover24h", "quoteVolume" });
    
    // Timestamp
    try mapping.addMapping("timestamp", &[_][]const u8{ "time", "timestamp" });
    
    // Required fields
    try mapping.addRequiredFields(.ticker, &[_][]const u8{ "price" });
    try mapping.addRequiredFields(.trade, &[_][]const u8{ "price", "size" });
    try mapping.addRequiredFields(.orderbook, &[_][]const u8{ "bids", "asks" });
    
    return mapping;
}

/// Binance field mapping
fn createBinanceMapping(allocator: std.mem.Allocator) !FieldMapping {
    var mapping = try FieldMapping.init(allocator, "binance");
    
    // Price fields
    try mapping.addMapping("price", &[_][]const u8{ "price", "lastPrice", "c" });
    try mapping.addMapping("bidPrice", &[_][]const u8{ "bidPrice", "b" });
    try mapping.addMapping("askPrice", &[_][]const u8{ "askPrice", "a" });
    try mapping.addMapping("highPrice", &[_][]const u8{ "highPrice", "h" });
    try mapping.addMapping("lowPrice", &[_][]const u8{ "lowPrice", "l" });
    try mapping.addMapping("openPrice", &[_][]const u8{ "openPrice", "o" });
    
    // Size fields
    try mapping.addMapping("size", &[_][]const u8{ "qty", "quantity", "origQty" });
    try mapping.addMapping("bidSize", &[_][]const u8{ "bidQty", "B" });
    try mapping.addMapping("askSize", &[_][]const u8{ "askQty", "A" });
    try mapping.addMapping("amount", &[_][]const u8{ "qty", "origQty", "executedQty" });
    
    // Volume fields
    try mapping.addMapping("volume", &[_][]const u8{ "volume", "v", "baseVolume" });
    try mapping.addMapping("quoteVolume", &[_][]const u8{ "quoteVolume", "q" });
    
    // Timestamp
    try mapping.addMapping("timestamp", &[_][]const u8{ "time", "E", "timestamp" });
    
    // Required fields
    try mapping.addRequiredFields(.ticker, &[_][]const u8{ "price" });
    try mapping.addRequiredFields(.trade, &[_][]const u8{ "price", "size" });
    try mapping.addRequiredFields(.orderbook, &[_][]const u8{ "bids", "asks" });
    
    return mapping;
}

/// Kraken field mapping (includes symbol mapping like XBT -> BTC)
fn createKrakenMapping(allocator: std.mem.Allocator) !FieldMapping {
    var mapping = try FieldMapping.init(allocator, "kraken");
    
    // Price fields
    try mapping.addMapping("price", &[_][]const u8{ "c", "price", "last" });
    try mapping.addMapping("bidPrice", &[_][]const u8{ "b", "bid" });
    try mapping.addMapping("askPrice", &[_][]const u8{ "a", "ask" });
    try mapping.addMapping("highPrice", &[_][]const u8{ "h", "high" });
    try mapping.addMapping("lowPrice", &[_][]const u8{ "l", "low" });
    try mapping.addMapping("openPrice", &[_][]const u8{ "o", "open" });
    
    // Size fields
    try mapping.addMapping("size", &[_][]const u8{ "vol", "volume", "size" });
    try mapping.addMapping("amount", &[_][]const u8{ "vol", "amount" });
    
    // Volume fields
    try mapping.addMapping("volume", &[_][]const u8{ "v", "vol", "volume" });
    try mapping.addMapping("quoteVolume", &[_][]const u8{ "p", "quoteVolume" });
    
    // Timestamp
    try mapping.addMapping("timestamp", &[_][]const u8{ "time", "timestamp" });
    
    // Required fields
    try mapping.addRequiredFields(.ticker, &[_][]const u8{ "price" });
    try mapping.addRequiredFields(.trade, &[_][]const u8{ "price", "size" });
    try mapping.addRequiredFields(.orderbook, &[_][]const u8{ "bids", "asks" });
    
    return mapping;
}

/// Hyperliquid field mapping (DEX with px/sz notation)
fn createHyperliquidMapping(allocator: std.mem.Allocator) !FieldMapping {
    var mapping = try FieldMapping.init(allocator, "hyperliquid");
    
    // Price fields - Hyperliquid uses "px" extensively
    try mapping.addMapping("price", &[_][]const u8{ "px", "price" });
    try mapping.addMapping("bidPrice", &[_][]const u8{ "px", "bidPrice" }); // In orderbook, px is in array
    try mapping.addMapping("askPrice", &[_][]const u8{ "px", "askPrice" });
    try mapping.addMapping("midPrice", &[_][]const u8{ "midPx", "mid" });
    try mapping.addMapping("markPrice", &[_][]const u8{ "markPx", "mark" });
    try mapping.addMapping("openPrice", &[_][]const u8{ "prevDayPx", "open" });
    try mapping.addMapping("prevDayPrice", &[_][]const u8{ "prevDayPx" });
    
    // Size fields - Hyperliquid uses "sz"
    try mapping.addMapping("size", &[_][]const u8{ "sz", "size" });
    try mapping.addMapping("bidSize", &[_][]const u8{ "sz", "bidSize" });
    try mapping.addMapping("askSize", &[_][]const u8{ "sz", "askSize" });
    try mapping.addMapping("amount", &[_][]const u8{ "sz", "amount" });
    
    // Volume fields
    try mapping.addMapping("volume", &[_][]const u8{ "dayNtlVlm", "volume" });
    try mapping.addMapping("openInterest", &[_][]const u8{ "openInterest", "oi" });
    
    // Timestamp - Hyperliquid uses "time" in milliseconds
    try mapping.addMapping("timestamp", &[_][]const u8{ "time", "timestamp" });
    
    // Market info
    try mapping.addMapping("symbol", &[_][]const u8{ "name", "coin", "symbol" });
    try mapping.addMapping("baseCoin", &[_][]const u8{ "name", "baseCoin" });
    
    // Required fields per operation
    try mapping.addRequiredFields(.ticker, &[_][]const u8{ "price" });
    try mapping.addRequiredFields(.trade, &[_][]const u8{ "price", "size", "timestamp" });
    try mapping.addRequiredFields(.orderbook, &[_][]const u8{ "levels" }); // Hyperliquid uses "levels" for bids/asks
    try mapping.addRequiredFields(.market, &[_][]const u8{ "symbol" });
    try mapping.addRequiredFields(.order, &[_][]const u8{ "price", "size" });
    
    return mapping;
}

/// Generic/default field mapping for exchanges without specific configuration
fn createGenericMapping(allocator: std.mem.Allocator) !FieldMapping {
    var mapping = try FieldMapping.init(allocator, "generic");
    
    // Standard field names only (no exchange-specific variants)
    try mapping.addMapping("price", &[_][]const u8{ "price", "last", "lastPrice" });
    try mapping.addMapping("bidPrice", &[_][]const u8{ "bid", "bidPrice" });
    try mapping.addMapping("askPrice", &[_][]const u8{ "ask", "askPrice" });
    try mapping.addMapping("size", &[_][]const u8{ "size", "amount", "qty" });
    try mapping.addMapping("volume", &[_][]const u8{ "volume", "vol" });
    try mapping.addMapping("timestamp", &[_][]const u8{ "timestamp", "time" });
    
    return mapping;
}

// ==================== Tests ====================

test "field mapper - OKX mapping" {
    const allocator = std.testing.allocator;
    
    var mapping = try createOkxMapping(allocator);
    defer mapping.deinit();
    
    const price_fields = mapping.getExchangeFields("price").?;
    try std.testing.expectEqualStrings("px", price_fields[0]);
    try std.testing.expectEqualStrings("lastPx", price_fields[1]);
}

test "field mapper - validation" {
    const allocator = std.testing.allocator;
    
    var mapping = try createOkxMapping(allocator);
    defer mapping.deinit();
    
    const json_str =
        \\{"px": 50000, "sz": 1.5, "ts": 1234567890}
    ;
    
    var parser = json.JsonParser.init(allocator);
    const parsed = try parser.parse(json_str);
    defer parsed.deinit();
    
    const required = [_][]const u8{ "price", "size", "timestamp" };
    const result = try FieldMapperUtils.validateFields(
        allocator,
        parsed.value,
        &required,
        &mapping,
    );
    defer result.deinit(allocator);
    
    try std.testing.expect(result.valid);
    try std.testing.expectEqual(@as(usize, 0), result.missing_fields.len);
}

test "field mapper - missing fields" {
    const allocator = std.testing.allocator;
    
    var mapping = try createOkxMapping(allocator);
    defer mapping.deinit();
    
    const json_str =
        \\{"px": 50000}
    ;
    
    var parser = json.JsonParser.init(allocator);
    const parsed = try parser.parse(json_str);
    defer parsed.deinit();
    
    const required = [_][]const u8{ "price", "size", "timestamp" };
    const result = try FieldMapperUtils.validateFields(
        allocator,
        parsed.value,
        &required,
        &mapping,
    );
    defer result.deinit(allocator);
    
    try std.testing.expect(!result.valid);
    try std.testing.expectEqual(@as(usize, 2), result.missing_fields.len);
}

test "field mapper - get field with mapping" {
    const allocator = std.testing.allocator;
    
    var mapping = try createOkxMapping(allocator);
    defer mapping.deinit();
    
    const json_str =
        \\{"px": 50000, "sz": 1.5}
    ;
    
    var parser = json.JsonParser.init(allocator);
    const parsed = try parser.parse(json_str);
    defer parsed.deinit();
    
    const price = FieldMapperUtils.getFloatField(
        &parser,
        parsed.value,
        "price",
        &mapping,
        0,
    );
    
    try std.testing.expectEqual(@as(f64, 50000), price);
    
    const size = FieldMapperUtils.getFloatField(
        &parser,
        parsed.value,
        "size",
        &mapping,
        0,
    );
    
    try std.testing.expectEqual(@as(f64, 1.5), size);
}
