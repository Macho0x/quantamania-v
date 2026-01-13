// WebSocket Types
// Phase 3.2 - WebSocket Support

const std = @import("std");

// WebSocket subscription types
pub const SubscriptionType = enum {
    ticker,
    orderbook,
    trades,
    ohlcv,
    orders,
    balance,
    positions,
};

// WebSocket message types
pub const WebSocketMessageType = enum {
    subscribe,
    unsubscribe,
    data,
    error,
    ping,
    pong,
};

// WebSocket subscription request
pub const SubscriptionRequest = struct {
    subscription_type: SubscriptionType,
    symbol: []const u8,
    timeframe: ?[]const u8,
    limit: ?usize,
    callback: ?fn ([]const u8) void,
    
    pub fn init(allocator: std.mem.Allocator, subscription_type: SubscriptionType, symbol: []const u8, timeframe: ?[]const u8, limit: ?usize, callback: ?fn ([]const u8) void) !SubscriptionRequest {
        return .{
            .subscription_type = subscription_type,
            .symbol = try allocator.dupe(u8, symbol),
            .timeframe = if (timeframe) |tf| try allocator.dupe(u8, tf) else null,
            .limit = limit,
            .callback = callback,
        };
    }
    
    pub fn deinit(self: *SubscriptionRequest, allocator: std.mem.Allocator) void {
        allocator.free(self.symbol);
        if (self.timeframe) |tf| {
            allocator.free(tf);
        }
    }
};

// WebSocket subscription response
pub const SubscriptionResponse = struct {
    subscription_id: []const u8,
    success: bool,
    error: ?[]const u8,
    
    pub fn init(allocator: std.mem.Allocator, subscription_id: []const u8, success: bool, error: ?[]const u8) !SubscriptionResponse {
        return .{
            .subscription_id = try allocator.dupe(u8, subscription_id),
            .success = success,
            .error = if (error) |e| try allocator.dupe(u8, e) else null,
        };
    }
    
    pub fn deinit(self: *SubscriptionResponse, allocator: std.mem.Allocator) void {
        allocator.free(self.subscription_id);
        if (self.error) |e| {
            allocator.free(e);
        }
    }
};

// WebSocket data message
pub const WebSocketDataMessage = struct {
    subscription_id: []const u8,
    message_type: WebSocketMessageType,
    data: []const u8,
    timestamp: i64,
    
    pub fn init(allocator: std.mem.Allocator, subscription_id: []const u8, message_type: WebSocketMessageType, data: []const u8, timestamp: i64) !WebSocketDataMessage {
        return .{
            .subscription_id = try allocator.dupe(u8, subscription_id),
            .message_type = message_type,
            .data = try allocator.dupe(u8, data),
            .timestamp = timestamp,
        };
    }
    
    pub fn deinit(self: *WebSocketDataMessage, allocator: std.mem.Allocator) void {
        allocator.free(self.subscription_id);
        allocator.free(self.data);
    }
};

// WebSocket connection status
pub const ConnectionStatus = enum {
    disconnected,
    connecting,
    connected,
    reconnecting,
    error,
};

// WebSocket statistics
pub const WebSocketStats = struct {
    messages_sent: u64,
    messages_received: u64,
    bytes_sent: u64,
    bytes_received: u64,
    connection_time: i64,
    reconnect_count: u32,
    
    pub fn init() WebSocketStats {
        return .{
            .messages_sent = 0,
            .messages_received = 0,
            .bytes_sent = 0,
            .bytes_received = 0,
            .connection_time = 0,
            .reconnect_count = 0,
        };
    }
};