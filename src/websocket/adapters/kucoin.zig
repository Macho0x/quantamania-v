const std = @import("std");
const ws = @import("../ws.zig");
const types = @import("../types.zig");
const json = @import("../../utils/json.zig");
const time = @import("../../utils/time.zig");
const crypto = @import("../../utils/crypto.zig");

// Import models
const Ticker = @import("../../models/ticker.zig").Ticker;
const OrderBook = @import("../../models/orderbook.zig").OrderBook;
const Trade = @import("../../models/trade.zig").Trade;
const OHLCV = @import("../../models/ohlcv.zig").OHLCV;
const Balance = @import("../../models/balance.zig").Balance;
const Order = @import("../../models/order.zig").Order;

// KuCoin WebSocket Adapter
// Supports spot and futures trading with token-based authentication
pub const KucoinWebSocketAdapter = struct {
    allocator: std.mem.Allocator,
    client: ws.WebSocketClient,
    auth_token: ?[]const u8,
    token_expires_at: i64,
    ping_interval: i64,
    last_ping_time: i64,
    subscriptions: std.StringHashMap(Subscription),
    message_handlers: std.StringHashMap(MessageHandler),
    testnet: bool,
    
    const SPOT_WS_URL = "wss://ws-api.kucoin.com";
    const FUTURES_WS_URL = "wss://ws-api.kucoinfuture.com";
    const SPOT_WS_URL_SANDBOX = "wss://openapi-sandbox.kucoin.com";
    const FUTURES_WS_URL_SANDBOX = "wss://api-sandbox.kucoinfuture.com";
    const TOKEN_REFRESH_INTERVAL = 3600000; // 1 hour in milliseconds
    
    pub const Subscription = struct {
        subscription_type: types.SubscriptionType,
        symbol: []const u8,
        timeframe: ?[]const u8,
        limit: ?usize,
        channel: []const u8,
        callback: ?fn ([]const u8) void,
    };
    
    pub const MessageHandler = struct {
        handler_fn: fn ([]const u8) void,
        message_type: []const u8,
    };
    
    pub fn init(allocator: std.mem.Allocator, testnet: bool) !*KucoinWebSocketAdapter {
        const self = try allocator.create(KucoinWebSocketAdapter);
        errdefer allocator.destroy(self);
        
        const ws_url = if (testnet) SPOT_WS_URL_SANDBOX else SPOT_WS_URL;
        
        self.allocator = allocator;
        self.client = try ws.WebSocketClient.init(allocator, ws_url);
        self.auth_token = null;
        self.token_expires_at = 0;
        self.ping_interval = 18000; // 18 seconds
        self.last_ping_time = 0;
        self.subscriptions = std.StringHashMap(Subscription).init(allocator);
        self.message_handlers = std.StringHashMap(MessageHandler).init(allocator);
        self.testnet = testnet;
        
        return self;
    }
    
    pub fn deinit(self: *KucoinWebSocketAdapter) void {
        // Clean up resources
        if (self.auth_token) |token| {
            self.allocator.free(token);
        }
        
        var sub_iter = self.subscriptions.iterator();
        while (sub_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.cleanupSubscription(entry.value_ptr.*);
        }
        self.subscriptions.deinit();
        
        var handler_iter = self.message_handlers.iterator();
        while (handler_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.message_handlers.deinit();
        
        self.client.deinit();
        self.allocator.destroy(self);
    }
    
    fn cleanupSubscription(self: *KucoinWebSocketAdapter, sub: *Subscription) void {
        self.allocator.free(sub.symbol);
        if (sub.timeframe) |tf| {
            self.allocator.free(tf);
        }
        self.allocator.free(sub.channel);
    }
    
    // Authenticate and get token for private channels
    pub fn authenticate(self: *KucoinWebSocketAdapter, api_key: []const u8, api_secret: []const u8, passphrase: []const u8) !void {
        // KuCoin WebSocket token endpoint
        const token_url = if (self.testnet) 
            "https://openapi-sandbox.kucoin.com/api/v1/bullet-private"
        else 
            "https://api.kucoin.com/api/v1/bullet-private";
        
        // Generate signature
        const timestamp = time.TimeUtils.now();
        const timestamp_str = try std.fmt.allocPrint(self.allocator, "{d}", .{timestamp});
        defer self.allocator.free(timestamp_str);
        
        const sign_string = timestamp_str;
        const signature = try crypto.Signer.hmacSha256Base64(self.allocator, api_secret, sign_string);
        const passphrase_sign = try crypto.Signer.hmacSha256Base64(self.allocator, api_secret, passphrase);
        
        // Create request body
        const request_body = try std.fmt.allocPrint(self.allocator, 
            \\{{
            \\"id": {d},
            \\"method": "PING",
            \\"params": {{
            \\"accessToken": "{s}",
            \\"signature": "{s}",
            \\"passphrase": "{s}",
            \\"timestamp": {d}
            \\}}
            \\}}
        , .{ timestamp, api_key, signature, passphrase_sign, timestamp });
        defer self.allocator.free(request_body);
        
        // Make HTTP request to get token
        var headers = std.StringHashMap([]const u8).init(self.allocator);
        defer {
            var iter = headers.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
                self.allocator.free(entry.value_ptr.*);
            }
            headers.deinit();
        }
        
        try headers.put(try self.allocator.dupe(u8, "Content-Type"), try self.allocator.dupe(u8, "application/json"));
        try headers.put(try self.allocator.dupe(u8, "KC-API-KEY"), try self.allocator.dupe(u8, api_key));
        try headers.put(try self.allocator.dupe(u8, "KC-API-SIGN"), try self.allocator.dupe(u8, signature));
        try headers.put(try self.allocator.dupe(u8, "KC-API-TIMESTAMP"), timestamp_str);
        try headers.put(try self.allocator.dupe(u8, "KC-API-PASSPHRASE"), try self.allocator.dupe(u8, passphrase_sign));
        try headers.put(try self.allocator.dupe(u8, "KC-API-KEY-VERSION"), try self.allocator.dupe(u8, "2"));
        
        // For simplicity, we'll simulate token response
        // In real implementation, make actual HTTP request
        const token = try self.allocator.dupe(u8, "mock_token_" ++ timestamp_str);
        self.auth_token = token;
        self.token_expires_at = timestamp + TOKEN_REFRESH_INTERVAL;
    }
    
    // Connect to WebSocket
    pub fn connect(self: *KucoinWebSocketAdapter) !void {
        try self.client.connect();
        
        // Send token if authenticated
        if (self.auth_token) |token| {
            try self.sendToken(token);
        }
    }
    
    fn sendToken(self: *KucoinWebSocketAdapter, token: []const u8) !void {
        const token_message = try std.fmt.allocPrint(self.allocator,
            \\{{
            \\"id": {d},
            \\"type": "auth",
            \\"token": "{s}"
            \\}}
        , .{ time.TimeUtils.now(), token });
        defer self.allocator.free(token_message);
        
        try self.client.sendText(token_message);
    }
    
    // Market Data Subscriptions
    
    pub fn watchTicker(self: *KucoinWebSocketAdapter, symbol: []const u8, callback: ?fn ([]const u8) void) !void {
        const channel = try std.fmt.allocPrint(self.allocator, "/market/ticker:{s}", .{symbol});
        defer self.allocator.free(channel);
        
        const sub_id = try self.allocator.dupe(u8, "ticker_");
        try sub_id.appendSlice(symbol);
        
        const subscription_request = try std.fmt.allocPrint(self.allocator,
            \\{{
            \\"id": {d},
            \\"type": "subscribe",
            \\"topic": "{s}",
            \\"privateChannel": false,
            \\"response": true
            \\}}
        , .{ time.TimeUtils.now(), channel });
        defer self.allocator.free(subscription_request);
        
        try self.client.sendText(subscription_request);
        
        // Store subscription
        const subscription = Subscription{
            .subscription_type = .ticker,
            .symbol = try self.allocator.dupe(u8, symbol),
            .timeframe = null,
            .limit = null,
            .channel = try self.allocator.dupe(u8, channel),
            .callback = callback,
        };
        
        try self.subscriptions.put(sub_id, subscription);
    }
    
    pub fn watchOrderBook(self: *KucoinWebSocketAdapter, symbol: []const u8, levels: usize, callback: ?fn ([]const u8) void) !void {
        const channel = try std.fmt.allocPrint(self.allocator, "/market/level{?d}:{s}", .{ if (levels == 20) 2 else null, symbol });
        defer self.allocator.free(channel);
        
        const sub_id = try std.fmt.allocPrint(self.allocator, "orderbook_{s}_{d}", .{ symbol, levels });
        
        const subscription_request = try std.fmt.allocPrint(self.allocator,
            \\{{
            \\"id": {d},
            \\"type": "subscribe",
            \\"topic": "{s}",
            \\"privateChannel": false,
            \\"response": true
            \\}}
        , .{ time.TimeUtils.now(), channel });
        defer self.allocator.free(subscription_request);
        
        try self.client.sendText(subscription_request);
        
        // Store subscription
        const subscription = Subscription{
            .subscription_type = .orderbook,
            .symbol = try self.allocator.dupe(u8, symbol),
            .timeframe = null,
            .limit = levels,
            .channel = try self.allocator.dupe(u8, channel),
            .callback = callback,
        };
        
        try self.subscriptions.put(sub_id, subscription);
    }
    
    pub fn watchTrades(self: *KucoinWebSocketAdapter, symbol: []const u8, callback: ?fn ([]const u8) void) !void {
        const channel = try std.fmt.allocPrint(self.allocator, "/market/match:{s}", .{symbol});
        defer self.allocator.free(channel);
        
        const sub_id = try std.fmt.allocPrint(self.allocator, "trades_{s}", .{symbol});
        
        const subscription_request = try std.fmt.allocPrint(self.allocator,
            \\{{
            \\"id": {d},
            \\"type": "subscribe",
            \\"topic": "{s}",
            \\"privateChannel": false,
            \\"response": true
            \\}}
        , .{ time.TimeUtils.now(), channel });
        defer self.allocator.free(subscription_request);
        
        try self.client.sendText(subscription_request);
        
        // Store subscription
        const subscription = Subscription{
            .subscription_type = .trades,
            .symbol = try self.allocator.dupe(u8, symbol),
            .timeframe = null,
            .limit = null,
            .channel = try self.allocator.dupe(u8, channel),
            .callback = callback,
        };
        
        try self.subscriptions.put(sub_id, subscription);
    }
    
    pub fn watchOHLCV(self: *KucoinWebSocketAdapter, symbol: []const u8, timeframe: []const u8, callback: ?fn ([]const u8) void) !void {
        const channel = try std.fmt.allocPrint(self.allocator, "/market/candles:{s}_{s}", .{ symbol, timeframe });
        defer self.allocator.free(channel);
        
        const sub_id = try std.fmt.allocPrint(self.allocator, "ohlcv_{s}_{s}", .{ symbol, timeframe });
        
        const subscription_request = try std.fmt.allocPrint(self.allocator,
            \\{{
            \\"id": {d},
            \\"type": "subscribe",
            \\"topic": "{s}",
            \\"privateChannel": false,
            \\"response": true
            \\}}
        , .{ time.TimeUtils.now(), channel });
        defer self.allocator.free(subscription_request);
        
        try self.client.sendText(subscription_request);
        
        // Store subscription
        const subscription = Subscription{
            .subscription_type = .ohlcv,
            .symbol = try self.allocator.dupe(u8, symbol),
            .timeframe = try self.allocator.dupe(u8, timeframe),
            .limit = null,
            .channel = try self.allocator.dupe(u8, channel),
            .callback = callback,
        };
        
        try self.subscriptions.put(sub_id, subscription);
    }
    
    // Account Data Subscriptions (Authenticated)
    
    pub fn watchBalance(self: *KucoinWebSocketAdapter, callback: ?fn ([]const u8) void) !void {
        if (self.auth_token == null) {
            return error.AuthenticationRequired;
        }
        
        const channel = "/account/balance";
        
        const subscription_request = try std.fmt.allocPrint(self.allocator,
            \\{{
            \\"id": {d},
            \\"type": "subscribe",
            \\"topic": "{s}",
            \\"privateChannel": true,
            \\"response": true
            \\}}
        , .{ time.TimeUtils.now(), channel });
        defer self.allocator.free(subscription_request);
        
        try self.client.sendText(subscription_request);
        
        // Store subscription
        const subscription = Subscription{
            .subscription_type = .balance,
            .symbol = try self.allocator.dupe(u8, "ALL"),
            .timeframe = null,
            .limit = null,
            .channel = try self.allocator.dupe(u8, channel),
            .callback = callback,
        };
        
        try self.subscriptions.put(try self.allocator.dupe(u8, "balance"), subscription);
    }
    
    pub fn watchOrders(self: *KucoinWebSocketAdapter, symbol: []const u8, callback: ?fn ([]const u8) void) !void {
        if (self.auth_token == null) {
            return error.AuthenticationRequired;
        }
        
        const channel = try std.fmt.allocPrint(self.allocator, "/market/level2:{s}", .{symbol});
        defer self.allocator.free(channel);
        
        const sub_id = try std.fmt.allocPrint(self.allocator, "orders_{s}", .{symbol});
        
        const subscription_request = try std.fmt.allocPrint(self.allocator,
            \\{{
            \\"id": {d},
            \\"type": "subscribe",
            \\"topic": "{s}",
            \\"privateChannel": true,
            \\"response": true
            \\}}
        , .{ time.TimeUtils.now(), channel });
        defer self.allocator.free(subscription_request);
        
        try self.client.sendText(subscription_request);
        
        // Store subscription
        const subscription = Subscription{
            .subscription_type = .orders,
            .symbol = try self.allocator.dupe(u8, symbol),
            .timeframe = null,
            .limit = null,
            .channel = try self.allocator.dupe(u8, channel),
            .callback = callback,
        };
        
        try self.subscriptions.put(sub_id, subscription);
    }
    
    // Message processing
    pub fn handleMessage(self: *KucoinWebSocketAdapter, message: []const u8) !void {
        var parser = json.JsonParser.init(self.allocator);
        const parsed = try parser.parse(message);
        defer parsed.deinit();
        
        const root = parsed.value;
        
        // Handle different message types
        if (root.object.get("type")) |msg_type| {
            const type_str = switch (msg_type) {
                .string => |s| s,
                else => return,
            };
            
            if (std.mem.eql(u8, type_str, "message")) {
                try self.handleDataMessage(root);
            } else if (std.mem.eql(u8, type_str, "pong")) {
                try self.handlePong(root);
            } else if (std.mem.eql(u8, type_str, "error")) {
                try self.handleError(root);
            }
        }
        
        // Handle ping messages
        if (root.object.get("ping")) |ping_val| {
            const ping_time = switch (ping_val) {
                .integer => |i| i,
                else => return,
            };
            try self.handlePing(ping_time);
        }
    }
    
    fn handleDataMessage(self: *KucoinWebSocketAdapter, root: std.json.Value) !void {
        if (root.object.get("topic")) |topic| {
            const topic_str = switch (topic) {
                .string => |s| s,
                else => return,
            };
            
            if (root.object.get("data")) |data| {
                if (std.mem.indexOf(u8, topic_str, "/market/ticker:")) |_| {
                    try self.parseTickerMessage(data, topic_str);
                } else if (std.mem.indexOf(u8, topic_str, "/market/level")) |_| {
                    try self.parseOrderBookMessage(data, topic_str);
                } else if (std.mem.indexOf(u8, topic_str, "/market/match:")) |_| {
                    try self.parseTradeMessage(data, topic_str);
                } else if (std.mem.indexOf(u8, topic_str, "/market/candles:")) |_| {
                    try self.parseOHLCVMessage(data, topic_str);
                } else if (std.mem.indexOf(u8, topic_str, "/account/balance")) |_| {
                    try self.parseBalanceMessage(data);
                }
            }
        }
    }
    
    fn parseTickerMessage(self: *KucoinWebSocketAdapter, data: std.json.Value, topic: []const u8) !void {
        var parser = json.JsonParser.init(self.allocator);
        
        const price_str = parser.getString(data.object.get("price") orelse .{ .string = "0" }, "0");
        const size_str = parser.getString(data.object.get("size") orelse .{ .string = "0" }, "0");
        const sequence = parser.getInt(data.object.get("sequence") orelse .{ .integer = 0 }, 0);
        const time_val = parser.getInt(data.object.get("time") orelse .{ .integer = 0 }, 0);
        
        // Extract symbol from topic
        const symbol_start = std.mem.indexOf(u8, topic, ":").?;
        const symbol = topic[symbol_start + 1 ..];
        
        const ticker_data = try std.fmt.allocPrint(self.allocator,
            \\{{
            \\"symbol": "{s}",
            \\"price": {s},
            \\"size": {s},
            \\"sequence": {d},
            \\"timestamp": {d}
            \\}}
        , .{ symbol, price_str, size_str, sequence, time_val });
        defer self.allocator.free(ticker_data);
        
        // Find and call callback
        var iter = self.subscriptions.iterator();
        while (iter.next()) |entry| {
            const sub = entry.value_ptr.*;
            if (sub.subscription_type == .ticker and std.mem.eql(u8, sub.symbol, symbol)) {
                if (sub.callback) |callback| {
                    callback(ticker_data);
                }
                break;
            }
        }
    }
    
    fn parseOrderBookMessage(self: *KucoinWebSocketAdapter, data: std.json.Value, topic: []const u8) !void {
        var parser = json.JsonParser.init(self.allocator);
        
        // Extract symbol from topic
        const symbol_start = std.mem.indexOf(u8, topic, ":").?;
        const symbol = topic[symbol_start + 1 ..];
        
        // Parse bids and asks
        const bids_array = data.object.get("bids") orelse return;
        const asks_array = data.object.get("asks") orelse return;
        
        const orderbook_data = try std.fmt.allocPrint(self.allocator,
            \\{{
            \\"symbol": "{s}",
            \\"bids": {s},
            \\"asks": {s},
            \\"timestamp": {d}
            \\}}
        , .{ symbol, try parser.stringify(bids_array), try parser.stringify(asks_array), time.TimeUtils.now() });
        defer self.allocator.free(orderbook_data);
        
        // Find and call callback
        var iter = self.subscriptions.iterator();
        while (iter.next()) |entry| {
            const sub = entry.value_ptr.*;
            if (sub.subscription_type == .orderbook and std.mem.eql(u8, sub.symbol, symbol)) {
                if (sub.callback) |callback| {
                    callback(orderbook_data);
                }
                break;
            }
        }
    }
    
    fn parseTradeMessage(self: *KucoinWebSocketAdapter, data: std.json.Value, topic: []const u8) !void {
        var parser = json.JsonParser.init(self.allocator);
        
        // Extract symbol from topic
        const symbol_start = std.mem.indexOf(u8, topic, ":").?;
        const symbol = topic[symbol_start + 1 ..];
        
        const trade_data = try parser.stringify(data);
        
        // Find and call callback
        var iter = self.subscriptions.iterator();
        while (iter.next()) |entry| {
            const sub = entry.value_ptr.*;
            if (sub.subscription_type == .trades and std.mem.eql(u8, sub.symbol, symbol)) {
                if (sub.callback) |callback| {
                    callback(trade_data);
                }
                break;
            }
        }
    }
    
    fn parseOHLCVMessage(self: *KucoinWebSocketAdapter, data: std.json.Value, topic: []const u8) !void {
        var parser = json.JsonParser.init(self.allocator);
        
        // Extract symbol and timeframe from topic
        const parts = std.mem.split(u8, topic, "_");
        const symbol_start = std.mem.indexOf(u8, topic, ":").?;
        const symbol = topic[symbol_start + 1 .. std.mem.indexOf(u8, topic, "_").?];
        
        const ohlcv_data = try parser.stringify(data);
        
        // Find and call callback
        var iter = self.subscriptions.iterator();
        while (iter.next()) |entry| {
            const sub = entry.value_ptr.*;
            if (sub.subscription_type == .ohlcv and std.mem.eql(u8, sub.symbol, symbol)) {
                if (sub.callback) |callback| {
                    callback(ohlcv_data);
                }
                break;
            }
        }
    }
    
    fn parseBalanceMessage(self: *KucoinWebSocketAdapter, data: std.json.Value) !void {
        var parser = json.JsonParser.init(self.allocator);
        const balance_data = try parser.stringify(data);
        
        // Find and call balance callback
        var iter = self.subscriptions.iterator();
        while (iter.next()) |entry| {
            const sub = entry.value_ptr.*;
            if (sub.subscription_type == .balance) {
                if (sub.callback) |callback| {
                    callback(balance_data);
                }
                break;
            }
        }
    }
    
    fn handlePing(self: *KucoinWebSocketAdapter, ping_time: i64) !void {
        const pong_message = try std.fmt.allocPrint(self.allocator,
            \\{{
            \\"pong": {d}
            \\}}
        , .{ping_time});
        defer self.allocator.free(pong_message);
        
        try self.client.sendText(pong_message);
    }
    
    fn handlePong(self: *KucoinWebSocketAdapter, root: std.json.Value) !void {
        // Handle pong response
        _ = root;
    }
    
    fn handleError(self: *KucoinWebSocketAdapter, root: std.json.Value) !void {
        // Handle error messages
        if (root.object.get("msg")) |msg| {
            const error_msg = switch (msg) {
                .string => |s| s,
                else => "Unknown error",
            };
            std.debug.print("KuCoin WebSocket Error: {s}\n", .{error_msg});
        }
    }
    
    // Utility functions
    pub fn isConnected(self: *KucoinWebSocketAdapter) bool {
        return self.client.isConnected();
    }
    
    pub fn disconnect(self: *KucoinWebSocketAdapter) void {
        self.client.close();
    }
    
    pub fn receiveMessage(self: *KucoinWebSocketAdapter) ![]const u8 {
        const ws_message = try self.client.recv(self.allocator);
        defer ws_message.deinit(self.allocator);
        return ws_message.data;
    }
    
    // Batch operations
    pub fn batchSubscribe(self: *KucoinWebSocketAdapter, subscriptions: []const BatchSubscriptionRequest) !void {
        // KuCoin supports batch subscriptions via multiple subscribe messages
        for (subscriptions) |sub| {
            switch (sub.subscription_type) {
                .ticker => try self.watchTicker(sub.symbol, sub.callback),
                .orderbook => try self.watchOrderBook(sub.symbol, sub.limit orelse 100, sub.callback),
                .trades => try self.watchTrades(sub.symbol, sub.callback),
                .ohlcv => try self.watchOHLCV(sub.symbol, sub.timeframe orelse "1hour", sub.callback),
                .balance => try self.watchBalance(sub.callback),
                .orders => try self.watchOrders(sub.symbol, sub.callback),
                else => continue,
            }
        }
    }
    
    pub const BatchSubscriptionRequest = struct {
        subscription_type: types.SubscriptionType,
        symbol: []const u8,
        timeframe: ?[]const u8,
        limit: ?usize,
        callback: ?fn ([]const u8) void,
    };
    
    // Unsubscribe
    pub fn unsubscribe(self: *KucoinWebSocketAdapter, subscription_id: []const u8) !void {
        if (self.subscriptions.get(subscription_id)) |subscription| {
            const unsubscribe_request = try std.fmt.allocPrint(self.allocator,
                \\{{
                \\"id": {d},
                \\"type": "unsubscribe",
                \\"topic": "{s}",
                \\"privateChannel": {s},
                \\"response": true
                \\}}
            , .{ time.TimeUtils.now(), subscription.channel, 
                 if (std.mem.indexOf(u8, subscription.channel, "/account/") != null) "true" else "false" });
            defer self.allocator.free(unsubscribe_request);
            
            try self.client.sendText(unsubscribe_request);
            self.subscriptions.remove(subscription_id);
        }
    }
};

// Error types
pub const KucoinWebSocketError = error{
    AuthenticationRequired,
    SubscriptionNotFound,
    InvalidSymbol,
    InvalidTimeframe,
    ConnectionFailed,
    TokenExpired,
    RateLimited,
};