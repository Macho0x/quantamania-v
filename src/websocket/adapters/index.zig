// WebSocket Adapters Module
// Central module for all exchange WebSocket adapters

const std = @import("std");

// Re-export all adapters
pub const KucoinWebSocketAdapter = @import("kucoin.zig").KucoinWebSocketAdapter;

// Re-export types
pub const SubscriptionType = @import("../../types.zig").SubscriptionType;
pub const WebSocketMessageType = @import("../../types.zig").WebSocketMessageType;
pub const SubscriptionRequest = @import("../../types.zig").SubscriptionRequest;
pub const SubscriptionResponse = @import("../../types.zig").SubscriptionResponse;
pub const WebSocketDataMessage = @import("../../types.zig").WebSocketDataMessage;
pub const ConnectionStatus = @import("../../types.zig").ConnectionStatus;
pub const WebSocketStats = @import("../../types.zig").WebSocketStats;

// KuCoin-specific types and errors
pub const KucoinWebSocketError = @import("kucoin.zig").KucoinWebSocketError;

// Adapter configuration constants
pub const AdaptersConfig = struct {
    pub const DEFAULT_TIMEOUT = 30000; // 30 seconds
    pub const PING_INTERVAL = 18000; // 18 seconds
    pub const RECONNECT_MAX_ATTEMPTS = 5;
    pub const TOKEN_REFRESH_INTERVAL = 3600000; // 1 hour
};

// Utility functions for adapter management
pub const AdapterUtils = struct {
    /// Create a new KuCoin WebSocket adapter
    pub fn createKucoinAdapter(allocator: std.mem.Allocator, testnet: bool) !*KucoinWebSocketAdapter {
        return try KucoinWebSocketAdapter.init(allocator, testnet);
    }
    
    /// Validate if a symbol is supported by KuCoin
    pub fn isValidKucoinSymbol(symbol: []const u8) bool {
        // Basic symbol validation - should contain dash and be uppercase
        if (std.mem.indexOf(u8, symbol, "-")) |_| {
            // Check for common patterns: BASE-QUOTE
            const parts = std.mem.split(u8, symbol, "-");
            const base = parts.next() orelse return false;
            const quote = parts.next() orelse return false;
            
            // Both parts should be non-empty and contain only alphanumeric characters
            return base.len > 0 and quote.len > 0 and
                   isAlnum(base) and isAlnum(quote);
        }
        return false;
    }
    
    /// Validate timeframe for OHLCV subscriptions
    pub fn isValidTimeframe(timeframe: []const u8) bool {
        const valid_timeframes = &[_][]const u8{
            "1min", "3min", "5min", "15min", "30min", 
            "1hour", "2hour", "4hour", "6hour", "8hour", "12hour", 
            "1day", "1week", "1month"
        };
        
        for (valid_timeframes) |valid_tf| {
            if (std.mem.eql(u8, timeframe, valid_tf)) {
                return true;
            }
        }
        return false;
    }
    
    /// Generate subscription ID for a channel
    pub fn generateSubscriptionId(subscription_type: SubscriptionType, symbol: []const u8, timeframe: ?[]const u8, limit: ?usize) ![]const u8 {
        var id = std.ArrayList(u8).init(std.heap.page_allocator);
        defer id.deinit();
        
        try id.appendSlice(@tagName(subscription_type));
        try id.appendSlice("_");
        try id.appendSlice(symbol);
        
        if (timeframe) |tf| {
            try id.appendSlice("_");
            try id.appendSlice(tf);
        }
        
        if (limit) |l| {
            try id.appendSlice("_");
            try std.fmt.format(id.writer(), "{}", .{l});
        }
        
        return try id.toOwnedSlice();
    }
    
    /// Helper function to check if string is alphanumeric
    fn isAlnum(s: []const u8) bool {
        for (s) |c| {
            if (!((c >= 'a' and c <= 'z') or 
                  (c >= 'A' and c <= 'Z') or 
                  (c >= '0' and c <= '9'))) {
                return false;
            }
        }
        return true;
    }
};

// Testing utilities
pub const TestUtils = struct {
    /// Create a test adapter with mock data
    pub fn createTestAdapter() !*KucoinWebSocketAdapter {
        return try KucoinWebSocketAdapter.init(std.heap.page_allocator, true);
    }
    
    /// Simulate a KuCoin message for testing
    pub fn simulateMessage(adapter: *KucoinWebSocketAdapter, message: []const u8) !void {
        try adapter.handleMessage(message);
    }
    
    /// Get test subscription requests
    pub fn getTestSubscriptions() []const KucoinWebSocketAdapter.BatchSubscriptionRequest {
        const ticker_callback = struct {
            fn callback(data: []const u8) void { _ = data; }
        }.callback;
        
        return &[_]KucoinWebSocketAdapter.BatchSubscriptionRequest{
            .{ .subscription_type = .ticker, .symbol = "BTC-USDT", .timeframe = null, .limit = null, .callback = ticker_callback },
            .{ .subscription_type = .orderbook, .symbol = "BTC-USDT", .timeframe = null, .limit = 20, .callback = ticker_callback },
            .{ .subscription_type = .trades, .symbol = "BTC-USDT", .timeframe = null, .limit = null, .callback = ticker_callback },
        };
    }
};

// Performance benchmarks
pub const Benchmarks = struct {
    /// Benchmark message parsing performance
    pub fn benchmarkMessageParsing(allocator: std.mem.Allocator) !f64 {
        const adapter = try KucoinWebSocketAdapter.init(allocator, true);
        defer adapter.deinit();
        
        const test_message = 
            \\{
            \\"type": "message",
            \\"topic": "/market/ticker:BTC-USDT",
            \\"data": {
                \\"sequence": 1234567,
                \\"price": "45234.56",
                \\"size": "0.01",
                \\"time": 1577836800000
            \\}
            \\}
        ;
        
        const start_time = std.time.nanoTimestamp();
        
        var i: usize = 0;
        while (i < 1000) : (i += 1) {
            try adapter.handleMessage(test_message);
        }
        
        const end_time = std.time.nanoTimestamp();
        const total_time = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000; // Convert to milliseconds
        
        return total_time / 1000.0; // Average time per message
    }
    
    /// Benchmark subscription management performance
    pub fn benchmarkSubscriptionManagement(allocator: std.mem.Allocator) !f64 {
        const adapter = try KucoinWebSocketAdapter.init(allocator, true);
        defer adapter.deinit();
        
        const symbols = &[_][]const u8{ "BTC-USDT", "ETH-USDT", "ADA-USDT", "DOT-USDT", "LINK-USDT" };
        
        const start_time = std.time.nanoTimestamp();
        
        for (symbols) |symbol| {
            try adapter.watchTicker(symbol, null);
        }
        
        const end_time = std.time.nanoTimestamp();
        const total_time = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000; // Convert to milliseconds
        
        return total_time; // Total time for subscriptions
    }
};

// Integration with main application
pub const Integration = struct {
    /// Initialize WebSocket manager with KuCoin adapter
    pub fn initializeKucoinManager(allocator: std.mem.Allocator, testnet: bool) !*KucoinWebSocketAdapter {
        const adapter = try KucoinWebSocketAdapter.init(allocator, testnet);
        
        // Set up default callbacks
        // In real application, these would be configured by the user
        
        return adapter;
    }
    
    /// Get default configuration for KuCoin adapter
    pub fn getDefaultConfig() KucoinWebSocketAdapter {
        return .{
            .allocator = undefined, // Will be set during init
            .client = undefined,    // Will be set during init
            .auth_token = null,
            .token_expires_at = 0,
            .ping_interval = AdaptersConfig.PING_INTERVAL,
            .last_ping_time = 0,
            .subscriptions = undefined, // Will be set during init
            .message_handlers = undefined, // Will be set during init
            .testnet = false,
        };
    }
};