// Binance WebSocket Adapter
// Provides real-time market data and account updates for Binance Spot and Futures

const std = @import("std");

const Ticker = @import("../../models/ticker.zig").Ticker;
const OHLCV = @import("../../models/ohlcv.zig").OHLCV;
const OrderBook = @import("../../models/orderbook.zig").OrderBook;
const OrderBookEntry = @import("../../models/orderbook.zig").OrderBookEntry;
const Trade = @import("../../models/trade.zig").Trade;
const Balance = @import("../../models/balance.zig").Balance;
const Order = @import("../../models/order.zig").Order;
const OrderType = @import("../../models/order.zig").OrderType;
const OrderSide = @import("../../models/order.zig").OrderSide;
const OrderStatus = @import("../../models/order.zig").OrderStatus;
const TradeType = @import("../../models/trade.zig").TradeType;
const types = @import("../../base/types.zig");

// Binance WebSocket specific types
pub const WebSocketTicker = struct {
    symbol: []const u8,
    price: f64,
    bid: f64,
    ask: f64,
    volume: f64,
    change_24h: f64,
    high_24h: f64,
    low_24h: f64,
    event_time: i64,
    quote_volume: f64,
};

pub const WebSocketOHLCV = struct {
    symbol: []const u8,
    open: f64,
    high: f64,
    low: f64,
    close: f64,
    volume: f64,
    close_time: i64,
    quote_asset_volume: f64,
    number_of_trades: u64,
    taker_buy_base_volume: f64,
    taker_buy_quote_volume: f64,
    start_time: i64,
};

pub const WebSocketOrderBook = struct {
    symbol: []const u8,
    last_update_id: i64,
    event_time: i64,
    first_update_id: i64,
    bids: []OrderBookEntry,
    asks: []OrderBookEntry,
};

pub const WebSocketTrade = struct {
    event_type: []const u8,
    event_time: i64,
    symbol: []const u8,
    trade_id: i64,
    price: f64,
    quantity: f64,
    buyer_order_id: i64,
    seller_order_id: i64,
    trade_time: i64,
    is_buyer_maker: bool,
};

pub const WebSocketBalance = struct {
    event_type: []const u8,
    event_time: i64,
    last_account_update: i64,
    balances: []WebSocketBalanceItem,
};

pub const WebSocketBalanceItem = struct {
    asset: []const u8,
    free: f64,
    locked: f64,
};

pub const WebSocketOrder = struct {
    event_type: []const u8,
    event_time: i64,
    symbol: []const u8,
    client_order_id: []const u8,
    side: OrderSide,
    order_type: OrderType,
    order_status: OrderStatus,
    order_id: i64,
    order_list_id: i64,
    price: f64,
    original_quantity: f64,
    executed_quantity: f64,
    cummulative_quote_qty: f64,
    order_time: i64,
    update_time: i64,
    is_maker: bool,
    commission: ?f64,
    commission_asset: ?[]const u8,
};

pub const BinanceWebSocketAdapter = struct {
    allocator: std.mem.Allocator,
    base_url: []const u8,
    is_futures: bool,

    // Base URLs for different endpoints
    const SPOT_WS_URL = "wss://stream.binance.com:9443/ws";
    const FUTURES_WS_URL = "wss://fstream.binance.com/ws";
    const TESTNET_WS_URL = "wss://testnet.binance.vision/ws";

    pub fn init(allocator: std.mem.Allocator, is_futures: bool, testnet: bool) !BinanceWebSocketAdapter {
        return .{
            .allocator = allocator,
            .base_url = if (testnet)
                try allocator.dupe(u8, TESTNET_WS_URL)
            else if (is_futures)
                try allocator.dupe(u8, FUTURES_WS_URL)
            else
                try allocator.dupe(u8, SPOT_WS_URL),
            .is_futures = is_futures,
        };
    }

    pub fn deinit(self: *BinanceWebSocketAdapter) void {
        self.allocator.free(self.base_url);
    }

    // Convert trading pair symbol to Binance format (lowercase, no slash)
    fn normalizeSymbol(allocator: std.mem.Allocator, symbol: []const u8) ![]const u8 {
        var buffer = std.ArrayList(u8).init(allocator);
        errdefer buffer.deinit();

        for (symbol) |c| {
            switch (c) {
                '/' => {},
                else => try buffer.append(std.ascii.toLower(c)),
            }
        }

        return buffer.toOwnedSlice();
    }

    // === Message Builders ===

    /// Build subscription message for ticker stream
    /// watchTicker("BTC/USDT") → "btcusdt@ticker"
    pub fn buildTickerMessage(self: *BinanceWebSocketAdapter, symbol: []const u8) ![]const u8 {
        const normalized = try self.normalizeSymbol(self.allocator, symbol);
        defer self.allocator.free(normalized);

        return std.fmt.allocPrint(self.allocator, "{s}@ticker", .{normalized});
    }

    /// Build subscription message for OHLCV stream
    /// watchOHLCV("BTC/USDT", "1h") → "btcusdt@klines_1h"
    pub fn buildOHLCVMessage(self: *BinanceWebSocketAdapter, symbol: []const u8, timeframe: []const u8) ![]const u8 {
        const normalized = try self.normalizeSymbol(self.allocator, symbol);
        defer self.allocator.free(normalized);

        return std.fmt.allocPrint(self.allocator, "{s}@klines_{s}", .{normalized, timeframe});
    }

    /// Build subscription message for order book depth stream
    /// watchOrderBook("BTC/USDT", 10) → "btcusdt@depth10@100ms"
    pub fn buildOrderBookMessage(self: *BinanceWebSocketAdapter, symbol: []const u8, depth: u32) ![]const u8 {
        const normalized = try self.normalizeSymbol(self.allocator, symbol);
        defer self.allocator.free(normalized);

        // Validate depth (5, 10, 20 are common)
        const depth_str = switch (depth) {
            5 => "5",
            10 => "10",
            20 => "20",
            50 => "50",
            100 => "100",
            500 => "500",
            1000 => "1000",
            else => "10", // default to 10
        };

        // For futures, use different update speeds
        if (self.is_futures) {
            return std.fmt.allocPrint(self.allocator, "{s}@depth{s}@100ms", .{normalized, depth_str});
        } else {
            return std.fmt.allocPrint(self.allocator, "{s}@depth{s}", .{normalized, depth_str});
        }
    }

    /// Build subscription message for trades stream
    /// watchTrades("BTC/USDT") → "btcusdt@trade"
    pub fn buildTradesMessage(self: *BinanceWebSocketAdapter, symbol: []const u8) ![]const u8 {
        const normalized = try self.normalizeSymbol(self.allocator, symbol);
        defer self.allocator.free(normalized);

        return std.fmt.allocPrint(self.allocator, "{s}@trade", .{normalized});
    }

    /// Build subscription message for aggregated trades stream
    pub fn buildAggTradesMessage(self: *BinanceWebSocketAdapter, symbol: []const u8) ![]const u8 {
        const normalized = try self.normalizeSymbol(self.allocator, symbol);
        defer self.allocator.free(normalized);

        return std.fmt.allocPrint(self.allocator, "{s}@aggTrade", .{normalized});
    }

    /// Build listen key subscription for account data
    /// watchBalance() → "/<listen_key>" (appended to base URL)
    pub fn buildListenKeyPath(self: *BinanceWebSocketAdapter, listen_key: []const u8) ![]const u8 {
        return std.fmt.allocPrint(self.allocator, "/{s}", .{listen_key});
    }

    // === Data Parsers ===

    /// Parse ticker data from JSON
    /// Binance format: {"e":"24hrTicker","E":1630000000000,"s":"BTCUSDT","p":"45000.00",...}
    pub fn parseTickerData(self: *BinanceWebSocketAdapter, json_data: []const u8) !WebSocketTicker {
        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, json_data, .{});
        defer parsed.deinit();

        const obj = parsed.value.object;
        
        return .{
            .symbol = try self.allocator.dupe(u8, obj.get("s").?.string),
            .price = try std.fmt.parseFloat(f64, obj.get("c").?.string),
            .bid = try std.fmt.parseFloat(f64, obj.get("b").?.string),
            .ask = try std.fmt.parseFloat(f64, obj.get("a").?.string),
            .volume = try std.fmt.parseFloat(f64, obj.get("v").?.string),
            .change_24h = try std.fmt.parseFloat(f64, obj.get("P").?.string),
            .high_24h = try std.fmt.parseFloat(f64, obj.get("h").?.string),
            .low_24h = try std.fmt.parseFloat(f64, obj.get("l").?.string),
            .event_time = obj.get("E").?.integer,
            .quote_volume = try std.fmt.parseFloat(f64, obj.get("q").?.string),
        };
    }

    /// Parse OHLCV data from JSON
    /// Binance format: {"e":"kline","E":1630000000000,"s":"BTCUSDT","k":{"t":1630000000000,"T":1630003599999,"s":"BTCUSDT","o":"45000.00",...}}
    pub fn parseOHLCVData(self: *BinanceWebSocketAdapter, json_data: []const u8) !WebSocketOHLCV {
        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, json_data, .{});
        defer parsed.deinit();

        const obj = parsed.value.object;
        const kline = obj.get("k").?.object;
        
        return .{
            .symbol = try self.allocator.dupe(u8, obj.get("s").?.string),
            .open = try std.fmt.parseFloat(f64, kline.get("o").?.string),
            .high = try std.fmt.parseFloat(f64, kline.get("h").?.string),
            .low = try std.fmt.parseFloat(f64, kline.get("l").?.string),
            .close = try std.fmt.parseFloat(f64, kline.get("c").?.string),
            .volume = try std.fmt.parseFloat(f64, kline.get("v").?.string),
            .close_time = kline.get("T").?.integer,
            .quote_asset_volume = try std.fmt.parseFloat(f64, kline.get("q").?.string),
            .number_of_trades = @intCast(kline.get("n").?.integer),
            .taker_buy_base_volume = try std.fmt.parseFloat(f64, kline.get("V").?.string),
            .taker_buy_quote_volume = try std.fmt.parseFloat(f64, kline.get("Q").?.string),
            .start_time = kline.get("t").?.integer,
        };
    }

    /// Parse order book data from JSON
    /// Binance format: {"lastUpdateId":160,"bids":[["45000.00","0.5",[]]],"asks":[["45001.00","0.3",[]]]}
    pub fn parseOrderBookData(self: *BinanceWebSocketAdapter, json_data: []const u8) !WebSocketOrderBook {
        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, json_data, .{});
        defer parsed.deinit();

        const obj = parsed.value.object;
        
        // Parse bids
        const bids_array = obj.get("bids").?.array;
        var bids = try self.allocator.alloc(OrderBookEntry, bids_array.items.len);
        errdefer {
            for (bids) |*bid| {
                self.allocator.free(bid);
            }
            self.allocator.free(bids);
        }

        for (bids_array.items, 0..) |bid_item, i| {
            const bid_arr = bid_item.array;
            const price = try std.fmt.parseFloat(f64, bid_arr.items[0].string);
            const amount = try std.fmt.parseFloat(f64, bid_arr.items[1].string);
            
            bids[i] = try self.allocator.create(OrderBookEntry);
            bids[i].* = .{
                .price = price,
                .amount = amount,
                .timestamp = std.time.timestamp(),
                .orderCount = null,
            };
        }

        // Parse asks
        const asks_array = obj.get("asks").?.array;
        var asks = try self.allocator.alloc(OrderBookEntry, asks_array.items.len);
        errdefer {
            for (asks) |*ask| {
                self.allocator.free(ask);
            }
            self.allocator.free(asks);
        }

        for (asks_array.items, 0..) |ask_item, i| {
            const ask_arr = ask_item.array;
            const price = try std.fmt.parseFloat(f64, ask_arr.items[0].string);
            const amount = try std.fmt.parseFloat(f64, ask_arr.items[1].string);
            
            asks[i] = try self.allocator.create(OrderBookEntry);
            asks[i].* = .{
                .price = price,
                .amount = amount,
                .timestamp = std.time.timestamp(),
                .orderCount = null,
            };
        }

        return .{
            .symbol = try self.allocator.dupe(u8, obj.get("s").?.string orelse "UNKNOWN"),
            .last_update_id = obj.get("lastUpdateId").?.integer,
            .event_time = if (obj.get("E")) |e| e.integer else 0,
            .first_update_id = if (obj.get("U")) |u| u.integer else 0,
            .bids = bids,
            .asks = asks,
        };
    }

    /// Parse trade data from JSON
    /// Binance format: {"e":"trade","E":1630000000000,"s":"BTCUSDT","t":12345,"p":"45000.00",...}
    pub fn parseTradeData(self: *BinanceWebSocketAdapter, json_data: []const u8) !WebSocketTrade {
        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, json_data, .{});
        defer parsed.deinit();

        const obj = parsed.value.object;
        
        return .{
            .event_type = try self.allocator.dupe(u8, obj.get("e").?.string),
            .event_time = obj.get("E").?.integer,
            .symbol = try self.allocator.dupe(u8, obj.get("s").?.string),
            .trade_id = obj.get("t").?.integer,
            .price = try std.fmt.parseFloat(f64, obj.get("p").?.string),
            .quantity = try std.fmt.parseFloat(f64, obj.get("q").?.string),
            .buyer_order_id = obj.get("b").?.integer,
            .seller_order_id = obj.get("a").?.integer,
            .trade_time = obj.get("T").?.integer,
            .is_buyer_maker = obj.get("m").?.bool,
        };
    }

    /// Parse aggregated trade data from JSON
    pub fn parseAggTradeData(self: *BinanceWebSocketAdapter, json_data: []const u8) !WebSocketTrade {
        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, json_data, .{});
        defer parsed.deinit();

        const obj = parsed.value.object;
        
        return .{
            .event_type = try self.allocator.dupe(u8, obj.get("e").?.string),
            .event_time = obj.get("E").?.integer,
            .symbol = try self.allocator.dupe(u8, obj.get("s").?.string),
            .trade_id = obj.get("a").?.integer,
            .price = try std.fmt.parseFloat(f64, obj.get("p").?.string),
            .quantity = try std.fmt.parseFloat(f64, obj.get("q").?.string),
            .buyer_order_id = 0, // Not available in agg trades
            .seller_order_id = 0,
            .trade_time = obj.get("T").?.integer,
            .is_buyer_maker = obj.get("m").?.bool,
        };
    }

    /// Parse balance data from JSON (outboundAccountPosition event)
    /// Binance format: {"e":"outboundAccountPosition","E":1630000000000,"u":1630000000000,"B":[{"a":"BTC","f":"1.5","l":"0.5"}]}
    pub fn parseBalanceData(self: *BinanceWebSocketAdapter, json_data: []const u8) !WebSocketBalance {
        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, json_data, .{});
        defer parsed.deinit();

        const obj = parsed.value.object;
        
        // Parse balances array
        const balances_array = obj.get("B").?.array;
        var balances = try self.allocator.alloc(WebSocketBalanceItem, balances_array.items.len);
        
        for (balances_array.items, 0..) |balance_item, i| {
            const balance_obj = balance_item.object;
            balances[i] = .{
                .asset = try self.allocator.dupe(u8, balance_obj.get("a").?.string),
                .free = try std.fmt.parseFloat(f64, balance_obj.get("f").?.string),
                .locked = try std.fmt.parseFloat(f64, balance_obj.get("l").?.string),
            };
        }

        return .{
            .event_type = try self.allocator.dupe(u8, obj.get("e").?.string),
            .event_time = obj.get("E").?.integer,
            .last_account_update = obj.get("u").?.integer,
            .balances = balances,
        };
    }

    /// Parse order data from JSON (executionReport event)
    /// Binance format: {"e":"executionReport","E":1630000000000,"s":"BTCUSDT","c":"ORDER123","S":"BUY",...}
    pub fn parseOrderData(self: *BinanceWebSocketAdapter, json_data: []const u8) !WebSocketOrder {
        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, json_data, .{});
        defer parsed.deinit();

        const obj = parsed.value.object;
        
        // Parse order type
        const order_type_str = obj.get("o").?.string;
        const order_type = parseOrderType(order_type_str);
        
        // Parse order side
        const side_str = obj.get("S").?.string;
        const side = if (std.mem.eql(u8, side_str, "BUY")) OrderSide.buy else OrderSide.sell;
        
        // Parse order status
        const status_str = obj.get("X").?.string;
        const order_status = parseOrderStatus(status_str);
        
        return .{
            .event_type = try self.allocator.dupe(u8, obj.get("e").?.string),
            .event_time = obj.get("E").?.integer,
            .symbol = try self.allocator.dupe(u8, obj.get("s").?.string),
            .client_order_id = try self.allocator.dupe(u8, obj.get("c").?.string),
            .side = side,
            .order_type = order_type,
            .order_status = order_status,
            .order_id = obj.get("i").?.integer,
            .order_list_id = if (obj.get("g")) |g| g.integer else -1,
            .price = try std.fmt.parseFloat(f64, obj.get("p").?.string),
            .original_quantity = try std.fmt.parseFloat(f64, obj.get("q").?.string),
            .executed_quantity = try std.fmt.parseFloat(f64, obj.get("z").?.string),
            .cummulative_quote_qty = try std.fmt.parseFloat(f64, obj.get("Z").?.string),
            .order_time = obj.get("T").?.integer,
            .update_time = obj.get("O").?.integer,
            .is_maker = obj.get("m").?.bool,
            .commission = if (obj.get("n")) |n| try std.fmt.parseFloat(f64, n.string) else null,
            .commission_asset = if (obj.get("N")) |N| try self.allocator.dupe(u8, N.string) else null,
        };
    }

    // === Helper Functions ===

    fn parseOrderType(type_str: []const u8) OrderType {
        if (std.mem.eql(u8, type_str, "MARKET")) return OrderType.market;
        if (std.mem.eql(u8, type_str, "LIMIT")) return OrderType.limit;
        if (std.mem.eql(u8, type_str, "STOP")) return OrderType.stop;
        if (std.mem.eql(u8, type_str, "STOP_MARKET")) return OrderType.stop;
        if (std.mem.eql(u8, type_str, "STOP_LIMIT")) return OrderType.stop_limit;
        if (std.mem.eql(u8, type_str, "TAKE_PROFIT")) return OrderType.take_profit;
        if (std.mem.eql(u8, type_str, "TAKE_PROFIT_MARKET")) return OrderType.take_profit;
        if (std.mem.eql(u8, type_str, "TAKE_PROFIT_LIMIT")) return OrderType.take_profit_limit;
        if (std.mem.eql(u8, type_str, "TRAILING_STOP_MARKET")) return OrderType.trailing_stop;
        return OrderType.limit; // default
    }

    fn parseOrderStatus(status_str: []const u8) OrderStatus {
        if (std.mem.eql(u8, status_str, "NEW")) return OrderStatus.open;
        if (std.mem.eql(u8, status_str, "PARTIALLY_FILLED")) return OrderStatus.open;
        if (std.mem.eql(u8, status_str, "FILLED")) return OrderStatus.closed;
        if (std.mem.eql(u8, status_str, "CANCELED")) return OrderStatus.canceled;
        if (std.mem.eql(u8, status_str, "EXPIRED")) return OrderStatus.expired;
        if (std.mem.eql(u8, status_str, "REJECTED")) return OrderStatus.rejected;
        if (std.mem.eql(u8, status_str, "PENDING_CANCEL")) return OrderStatus.pending;
        return OrderStatus.open; // default
    }

    // === Subscription Stream Builder ===

    /// Build combined subscription for multiple streams
    /// Binance allows combining streams: btcusdt@ticker/btcusdt@depth10
    pub fn buildCombinedSubscription(self: *BinanceWebSocketAdapter, streams: []const []const u8) ![]const u8 {
        if (streams.len == 0) return error.EmptyStreams;

        var buffer = std.ArrayList(u8).init(self.allocator);
        errdefer buffer.deinit();

        for (streams, 0..) |stream, i| {
            if (i > 0) try buffer.append('/');
            try buffer.appendSlice(stream);
        }

        return buffer.toOwnedSlice();
    }

    // Get base URL with path
    pub fn getFullUrl(self: *BinanceWebSocketAdapter, path: []const u8) ![]const u8 {
        return std.fmt.allocPrint(self.allocator, "{s}{s}", .{self.base_url, path});
    }

    // Cleanup WebSocket data structures
    pub fn cleanupWebSocketTicker(self: *BinanceWebSocketAdapter, ticker: *WebSocketTicker) void {
        _ = self;
        // No heap allocations in WebSocketTicker
    }

    pub fn cleanupWebSocketOHLCV(self: *BinanceWebSocketAdapter, ohlcv: *WebSocketOHLCV) void {
        self.allocator.free(ohlcv.symbol);
    }

    pub fn cleanupWebSocketOrderBook(self: *BinanceWebSocketAdapter, ob: *WebSocketOrderBook) void {
        self.allocator.free(ob.symbol);
        for (ob.bids) |bid| {
            self.allocator.free(bid);
        }
        self.allocator.free(ob.bids);
        for (ob.asks) |ask| {
            self.allocator.free(ask);
        }
        self.allocator.free(ob.asks);
    }

    pub fn cleanupWebSocketTrade(self: *BinanceWebSocketAdapter, trade: *WebSocketTrade) void {
        self.allocator.free(trade.event_type);
        self.allocator.free(trade.symbol);
    }

    pub fn cleanupWebSocketBalance(self: *BinanceWebSocketAdapter, balance: *WebSocketBalance) void {
        self.allocator.free(balance.event_type);
        for (balance.balances) |*b| {
            self.allocator.free(b.asset);
        }
        self.allocator.free(balance.balances);
    }

    pub fn cleanupWebSocketOrder(self: *BinanceWebSocketAdapter, order: *WebSocketOrder) void {
        self.allocator.free(order.event_type);
        self.allocator.free(order.symbol);
        self.allocator.free(order.client_order_id);
        if (order.commission_asset) |asset| {
            self.allocator.free(asset);
        }
    }
};
