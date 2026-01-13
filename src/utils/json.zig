const std = @import("std");
const types = @import("../base/types.zig");

// JSON parser with type conversion and error handling
pub const JsonParser = struct {
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator) JsonParser {
        return .{ .allocator = allocator };
    }
    
    // Parse JSON string and return parsed JSON value
    pub fn parse(self: *JsonParser, json_str: []const u8) !std.json.Parsed(std.json.Value) {
        var scanner = std.json.Scanner.initCompleteInput(self.allocator, json_str);
        defer scanner.deinit();
        
        return try std.json.parseFromTokenSource(std.json.Value, self.allocator, &scanner, .{});
    }
    
    // Parse JSON to a specific type
    pub fn parseTo(self: *JsonParser, comptime T: type, json_str: []const u8) !T {
        var stream = std.json.TokenStream.init(json_str);
        return try std.json.parse(T, &stream, .{ .allocator = self.allocator });
    }
    
    // Extract nested field using dot notation
    pub fn getNested(self: *JsonParser, root: std.json.Value, path: []const u8) !?std.json.Value {
        var current = root;
        var it = std.mem.tokenize(u8, path, ".");
        
        while (it.next()) |segment| {
            switch (current) {
                .object => |obj| {
                    const maybe_child = obj.get(segment);
                    if (maybe_child) |child| {
                        current = child;
                    } else {
                        return null;
                    }
                },
                else => return null,
            }
        }
        
        return current;
    }
    
    // Get string from an object field (convenience used across exchange implementations)
    pub fn getString(self: *JsonParser, obj: std.json.Value, key: []const u8, default: []const u8) ?[]const u8 {
        _ = self;
        const val = switch (obj) {
            .object => |o| o.get(key) orelse return default,
            else => return default,
        };

        return switch (val) {
            .string => |s| s,
            .number_string => |s| s,
            else => default,
        };
    }

    // Get string from an optional JSON value
    pub fn getStringValue(self: *JsonParser, value: ?std.json.Value, default: []const u8) []const u8 {
        _ = self;
        const v = value orelse return default;
        return switch (v) {
            .string => |s| s,
            .number_string => |s| s,
            else => default,
        };
    }
    
    // Get integer value
    pub fn getInt(self: *JsonParser, value: std.json.Value, default: i64) i64 {
        return switch (value) {
            .integer => |i| i,
            .float => |f| @intFromFloat(f),
            .string => |s| std.fmt.parseInt(i64, s, 10) catch default,
            .number_string => |s| std.fmt.parseInt(i64, s, 10) catch default,
            else => default,
        };
    }
    
    // Get float value
    pub fn getFloat(self: *JsonParser, value: std.json.Value, default: f64) f64 {
        return switch (value) {
            .float => |f| f,
            .integer => |i| @floatFromInt(i),
            .string => |s| std.fmt.parseFloat(f64, s) catch default,
            .number_string => |s| std.fmt.parseFloat(f64, s) catch default,
            else => default,
        };
    }
    
    // Get decimal value (for precise price handling)
    pub fn getDecimal(self: *JsonParser, value: std.json.Value, default: ?types.Decimal) !?types.Decimal {
        return switch (value) {
            .string => |s| types.Decimal.fromString(self.allocator, s) catch default,
            .float => |f| {
                const scaled = @as(i128, @intFromFloat(@round(f * 100_000_000)));
                return types.Decimal{ .value = scaled, .scale = 8 };
            },
            .integer => |i| types.Decimal{ .value = @as(i128, i) * 100_000_000, .scale = 8 },
            else => default,
        };
    }
    
    // Get boolean value
    pub fn getBool(self: *JsonParser, value: std.json.Value, default: bool) bool {
        return switch (value) {
            .bool => |b| b,
            .string => |s| std.mem.eql(u8, s, "true") or std.mem.eql(u8, s, "1"),
            .integer => |i| i != 0,
            else => default,
        };
    }
    
    // Get array of values
    pub fn getArray(self: *JsonParser, value: std.json.Value, default: ?[]const std.json.Value) ?[]const std.json.Value {
        return switch (value) {
            .array => |a| a.items,
            else => default,
        };
    }
    
    // Get object properties
    pub fn getObject(self: *JsonParser, value: std.json.Value, default: ?std.StringHashMap(std.json.Value)) ?std.StringHashMap(std.json.Value) {
        return switch (value) {
            .object => |o| o,
            else => default,
        };
    }
    
    // Check if field exists in object
    pub fn hasField(self: *JsonParser, obj: std.json.Value, field: []const u8) bool {
        return switch (obj) {
            .object => |o| o.contains(field),
            else => false,
        };
    }
    
    // Safe array access
    pub fn safeIndex(self: *JsonParser, array: std.json.Value, index: usize) ?std.json.Value {
        return switch (array) {
            .array => |a| if (index < a.items.len) a.items[index] else null,
            else => null,
        };
    }
};

// JSON serializer
pub const JsonSerializer = struct {
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator) JsonSerializer {
        return .{ .allocator = allocator };
    }
    
    // Serialize a struct to JSON string
    pub fn stringify(self: *JsonSerializer, value: anytype) ![]u8 {
        var buffer = std.ArrayList(u8).init(self.allocator);
        defer buffer.deinit();
        
        try std.json.stringify(value, .{}, buffer.writer());
        return buffer.toOwnedSlice();
    }
    
    // Serialize with custom options
    pub fn stringifyWithOptions(self: *JsonSerializer, value: anytype, options: std.json.StringifyOptions) ![]u8 {
        var buffer = std.ArrayList(u8).init(self.allocator);
        defer buffer.deinit();
        
        try std.json.stringify(value, options, buffer.writer());
        return buffer.toOwnedSlice();
    }
    
    // Convert value to JSON struct
    pub fn toJsonValue(self: *JsonSerializer, value: anytype) !std.json.Value {
        var buffer = std.ArrayList(u8).init(self.allocator);
        defer buffer.deinit();
        
        try std.json.stringify(value, .{}, buffer.writer());
        const json_str = buffer.toOwnedSlice();
        defer self.allocator.free(json_str);
        
        var parser = JsonParser.init(self.allocator);
        const parsed = try parser.parse(json_str);
        return parsed.value;
    }
};

// Common JSON helpers for CCXT
pub const CCXTJson = struct {
    // Extract OHLCV data from exchange response
    pub fn parseOHLCVArray(self: *JsonParser, array: []const std.json.Value) ![][6]f64 {
        var result = std.ArrayList([6]f64).init(self.allocator);
        defer result.deinit();
        
        for (array) |item| {
            const ohlcv_array = switch (item) {
                .array => |a| a.items,
                else => return error.InvalidOHLCVFormat,
            };
            
            if (ohlcv_array.len < 5) return error.InvalidOHLCVFormat;
            
            var ohlcv: [6]f64 = undefined;
            ohlcv[0] = self.getFloat(ohlcv_array[0], 0); // timestamp
            ohlcv[1] = self.getFloat(ohlcv_array[1], 0); // open
            ohlcv[2] = self.getFloat(ohlcv_array[2], 0); // high
            ohlcv[3] = self.getFloat(ohlcv_array[3], 0); // low
            ohlcv[4] = self.getFloat(ohlcv_array[4], 0); // close
            ohlcv[5] = if (ohlcv_array.len > 5) self.getFloat(ohlcv_array[5], 0) else 0; // volume
            
            try result.append(ohlcv);
        }
        
        return result.toOwnedSlice();
    }
    
    // Parse order book from exchange response
    pub fn parseOrderBook(self: *JsonParser, obj: std.json.Value, depth: u32) !struct {
        bids: [][2]f64,
        asks: [][2]f64,
        timestamp: i64,
    } {
        const bids = self.getArray(obj.get("bids") orelse return error.MissingBids, null) orelse 
            return error.MissingBids;
        const asks = self.getArray(obj.get("asks") orelse return error.MissingAsks, null) orelse 
            return error.MissingAsks;
        
        var parsed_bids = std.ArrayList([2]f64).init(self.allocator);
        defer parsed_bids.deinit();
        
        var parsed_asks = std.ArrayList([2]f64).init(self.allocator);
        defer parsed_asks.deinit();
        
        // Parse bids
        const bid_limit = @min(bids.len, depth);
        for (0..bid_limit) |i| {
            const bid_array = switch (bids[i]) {
                .array => |a| a.items,
                else => continue,
            };
            
            if (bid_array.len < 2) continue;
            
            const price = self.getFloat(bid_array[0], 0);
            const amount = self.getFloat(bid_array[1], 0);
            try parsed_bids.append(.{ price, amount });
        }
        
        // Parse asks
        const ask_limit = @min(asks.len, depth);
        for (0..ask_limit) |i| {
            const ask_array = switch (asks[i]) {
                .array => |a| a.items,
                else => continue,
            };
            
            if (ask_array.len < 2) continue;
            
            const price = self.getFloat(ask_array[0], 0);
            const amount = self.getFloat(ask_array[1], 0);
            try parsed_asks.append(.{ price, amount });
        }
        
        const timestamp = self.getInt(obj.get("timestamp") orelse 
            .{ .integer = 0 }, 0);
        
        return .{
            .bids = parsed_bids.toOwnedSlice(),
            .asks = parsed_asks.toOwnedSlice(),
            .timestamp = timestamp,
        };
    }
    
    // Parse ticker data from exchange response
    pub fn parseTicker(self: *JsonParser, obj: std.json.Value, symbol: []const u8) !struct {
        symbol: []const u8,
        timestamp: i64,
        high: ?f64,
        low: ?f64,
        bid: ?f64,
        bidVolume: ?f64,
        ask: ?f64,
        askVolume: ?f64,
        last: ?f64,
        baseVolume: ?f64,
        quoteVolume: ?f64,
        percentage: ?f64,
    } {
        const symbol_copy = try self.allocator.dupe(u8, symbol);
        
        return .{
            .symbol = symbol_copy,
            .timestamp = self.getInt(obj.get("timestamp") orelse 
                .{ .integer = std.time.milliTimestamp() }, std.time.milliTimestamp()),
            .high = self.getFloat(obj.get("high") orelse obj.get("high24h") orelse 
                .{ .float = 0 }, 0),
            .low = self.getFloat(obj.get("low") orelse obj.get("low24h") orelse 
                .{ .float = 0 }, 0),
            .bid = self.getFloat(obj.get("bid") orelse 
                .{ .float = 0 }, 0),
            .bidVolume = self.getFloat(obj.get("bidVolume") orelse obj.get("bidSize") orelse 
                .{ .float = 0 }, 0),
            .ask = self.getFloat(obj.get("ask") orelse 
                .{ .float = 0 }, 0),
            .askVolume = self.getFloat(obj.get("askVolume") orelse obj.get("askSize") orelse 
                .{ .float = 0 }, 0),
            .last = self.getFloat(obj.get("last") orelse obj.get("lastPrice") orelse 
                .{ .float = 0 }, 0),
            .baseVolume = self.getFloat(obj.get("baseVolume") orelse obj.get("volume") orelse 
                .{ .float = 0 }, 0),
            .quoteVolume = self.getFloat(obj.get("quoteVolume") orelse obj.get("quoteVolume24h") orelse 
                .{ .float = 0 }, 0),
            .percentage = self.getFloat(obj.get("percentage") orelse obj.get("changePercent") orelse 
                .{ .float = 0 }, 0),
        };
    }
};