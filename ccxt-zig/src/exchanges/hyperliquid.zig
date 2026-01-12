// Hyperliquid Exchange Implementation
// Decentralized perpetuals exchange
// Phase 3.5 - DEX Support
//
// Note: Hyperliquid uses exchange-specific field names:
// - px = price
// - sz = size/amount
// - oid = order ID
// - cloid = client order ID
// - s = symbol
// - time = timestamp

const std = @import("std");
const base = @import("../base/exchange.zig");
const types = @import("../base/types.zig");
const models = @import("../models");
const utils = @import("../utils");
const errors = @import("../base/errors.zig");
const auth = @import("../base/auth.zig");
const http = @import("../base/http.zig");

pub const Hyperliquid = struct {
    base: base.Exchange,
    allocator: std.mem.Allocator,

    // Hyperliquid-specific field mappings for API format (px, sz, etc.)
    const HyperliquidFieldNames = struct {
        pub const PRICE = "px";
        pub const AMOUNT = "sz";
        pub const ORDER_ID = "oid";
        pub const CLIENT_ORDER_ID = "cloid";
        pub const SYMBOL = "s";
        pub const SIDE = "side";
        pub const TYPE = "orderType";
        pub const TIMESTAMP = "time";
        pub const FILLED = "filledSz";
        pub const REMAINING = "remainingSz";
        pub const AVG_PRICE = "avgPx";
        pub const BID_PRICE = "bidPx";
        pub const BID_AMOUNT = "bidSz";
        pub const ASK_PRICE = "askPx";
        pub const ASK_AMOUNT = "askSz";
        pub const LAST_PRICE = "lastPrice";
        pub const HIGH_24H = "high24h";
        pub const LOW_24H = "low24h";
        pub const VOLUME_24H = "volume24h";
        pub const STATUS = "status";
        pub const FUNDING_RATE = "fundingRate";
        pub const OPEN_INTEREST = "openInterest";
        pub const INDEX_PRICE = "indexPrice";
        pub const MARK_PRICE = "markPrice";
    };

    pub fn create(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) !Hyperliquid {
        var exchange = Hyperliquid{
            .base = try base.Exchange.init(allocator, "hyperliquid", "https://api.hyperliquid.xyz", auth_config),
            .allocator = allocator,
        };

        // Hyperliquid-specific configuration
        exchange.base.rate_limit = 100; // requests per second
        exchange.base.requires_signature = true;
        exchange.base.symbol_separator = "/";

        // Set Hyperliquid field mapping for exchange-specific API formats
        exchange.base.field_mapping = types.HyperliquidFieldMapping;

        return exchange;
    }
    
    pub fn deinit(self: *Hyperliquid) void {
        self.base.deinit();
    }
    
    // Testnet support
    pub fn createTestnet(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) !Hyperliquid {
        var exchange = Hyperliquid{
            .base = try base.Exchange.init(allocator, "hyperliquid", "https://api.hyperliquid.xyz/testnet", auth_config),
            .allocator = allocator,
        };

        // Hyperliquid-specific configuration
        exchange.base.rate_limit = 100; // requests per second
        exchange.base.requires_signature = true;
        exchange.base.symbol_separator = "/";

        // Set Hyperliquid field mapping for exchange-specific API formats
        exchange.base.field_mapping = types.HyperliquidFieldMapping;

        return exchange;
    }
    
    // Market Data Methods
    
    pub fn fetchMarkets(self: *Hyperliquid) ![]models.Market {
        const url = try self.base.buildUrl("/info");
        const response = try self.base.httpClient.get(url, null);
        defer response.deinit();
        
        // Parse Hyperliquid's market info format
        return try self.parseMarkets(response.body);
    }
    
    pub fn fetchTicker(self: *Hyperliquid, symbol: []const u8) !models.Ticker {
        const url = try self.base.buildUrl("/ticker");
        const params = try self.base.buildParams(.{
            .{ .key = "symbol", .value = symbol },
        });
        const response = try self.base.httpClient.get(url, params);
        defer response.deinit();
        
        // Parse Hyperliquid's ticker format
        return try self.parseTicker(response.body);
    }
    
    pub fn fetchOrderBook(self: *Hyperliquid, symbol: []const u8, limit: ?usize) !models.OrderBook {
        const url = try self.base.buildUrl("/orderbook");
        const params = try self.base.buildParams(.{
            .{ .key = "symbol", .value = symbol },
            .{ .key = "limit", .value = std.fmt.allocPrint(self.allocator, "{}", .{limit orelse 100}) },
        });
        const response = try self.base.httpClient.get(url, params);
        defer response.deinit();
        
        // Parse Hyperliquid's order book format
        return try self.parseOrderBook(response.body);
    }
    
    pub fn fetchOHLCV(self: *Hyperliquid, symbol: []const u8, timeframe: []const u8, since: ?i64, limit: ?usize) ![]models.OHLCV {
        const url = try self.base.buildUrl("/candles");
        const params = try self.base.buildParams(.{
            .{ .key = "symbol", .value = symbol },
            .{ .key = "timeframe", .value = timeframe },
            .{ .key = "limit", .value = std.fmt.allocPrint(self.allocator, "{}", .{limit orelse 100}) },
        });
        const response = try self.base.httpClient.get(url, params);
        defer response.deinit();
        
        // Parse Hyperliquid's OHLCV format
        return try self.parseOHLCV(response.body);
    }
    
    pub fn fetchTrades(self: *Hyperliquid, symbol: []const u8, since: ?i64, limit: ?usize) ![]models.Trade {
        const url = try self.base.buildUrl("/trades");
        const params = try self.base.buildParams(.{
            .{ .key = "symbol", .value = symbol },
            .{ .key = "limit", .value = std.fmt.allocPrint(self.allocator, "{}", .{limit orelse 100}) },
        });
        const response = try self.base.httpClient.get(url, params);
        defer response.deinit();
        
        // Parse Hyperliquid's trade format
        return try self.parseTrades(response.body);
    }
    
    // Private Methods (Wallet-based for DEX)
    
    pub fn fetchBalance(self: *Hyperliquid) !models.Balance {
        // Hyperliquid uses wallet-based authentication
        if (!self.base.auth_config.wallet_connected) {
            return error.AuthenticationError;
        }
        
        // Build URL for balance endpoint
        const url = try self.base.buildUrl("/balance");
        const response = try self.base.httpClient.get(url, null);
        defer response.deinit();
        
        return try self.parseBalance(response.body);
    }
    
    pub fn createOrder(self: *Hyperliquid, symbol: []const u8, order_type: models.OrderType, side: models.OrderSide, amount: f64, price: f64, params: ?base.OrderParams) !models.Order {
        // Hyperliquid uses wallet signing for orders
        if (!self.base.auth_config.wallet_connected) {
            return error.AuthenticationError;
        }
        
        // Build order payload
        const payload = try std.json.stringify(.{
            .symbol = symbol,
            .type = if (order_type == .market) "market" else "limit",
            .side = if (side == .buy) "buy" else "sell",
            .amount = amount,
            .price = price,
            .timestamp = std.time.milliTimestamp(),
        }, .{}, self.allocator);
        defer self.allocator.free(payload);
        
        // Build URL for order creation endpoint
        const url = try self.base.buildUrl("/order");
        const response = try self.base.httpClient.post(url, payload);
        defer response.deinit();
        
        return try self.parseOrder(response.body);
    }
    
    // Parsing Methods (Stub implementations)
    
    fn parseMarkets(self: *Hyperliquid, json_data: []const u8) ![]models.Market {
        const json = @import("../utils/json.zig");
        var parser = json.JsonParser.init(self.allocator);
        
        const parsed = try parser.parse(json_data);
        const root = parsed.value;
        
        var markets = std.ArrayList(models.Market).init(self.allocator);
        defer markets.deinit();
        
        // Parse Hyperliquid market info structure
        if (parser.hasField(root, "success") and parser.getBool(root.get("success") orelse .{ .bool = false }, false)) {
            if (parser.hasField(root, "markets")) {
                const markets_array = parser.getArray(root.get("markets") orelse .{ .array = .{ .items = &[_]std.json.Value{} } }, null) orelse return &.{};
                
                for (markets_array) |market_data| {
                    if (parser.hasField(market_data, "symbol") and parser.hasField(market_data, "base") and parser.hasField(market_data, "quote")) {
                        var market = try models.Market.init(self.allocator);
                        
                        market.id = try parser.getString(market_data.get("symbol") orelse .{ .string = "" }, null) orelse continue;
                        market.symbol = try parser.getString(market_data.get("symbol") orelse .{ .string = "" }, null) orelse continue;
                        market.base = try parser.getString(market_data.get("base") orelse .{ .string = "" }, null) orelse continue;
                        market.quote = try parser.getString(market_data.get("quote") orelse .{ .string = "" }, null) orelse continue;
                        market.active = parser.getBool(market_data.get("active") orelse .{ .bool = true }, true);
                        
                        // Hyperliquid is perpetuals-only
                        market.spot = false;
                        market.margin = false;
                        market.futures = true;
                        market.perpetual = true;
                        market.leverage = true;
                        
                        // Set leverage if available
                        if (parser.hasField(market_data, "maxLeverage")) {
                            market.leverage = parser.getFloat(market_data.get("maxLeverage") orelse .{ .float = 1.0 }, 1.0);
                        }
                        
                        try markets.append(market);
                    }
                }
            }
        }
        
        return try markets.toOwnedSlice();
    }
    
    fn parseTicker(self: *Hyperliquid, json_data: []const u8) !models.Ticker {
        const json = @import("../utils/json.zig");
        var parser = json.JsonParser.init(self.allocator);

        const parsed = try parser.parse(json_data);
        const root = parsed.value;

        var ticker = try models.Ticker.init(self.allocator);

        // Use Hyperliquid-specific field mappings (px for price, sz for amount)
        const m = &self.base.field_mapping;

        if (parser.hasField(root, "success") and parser.getBool(root.get("success") orelse .{ .bool = false }, false)) {
            if (parser.hasField(root, "data")) {
                const data = root.get("data") orelse return ticker;

                // Parse symbol (Hyperliquid uses "s" for symbol)
                const symbol_field = parser.getString(data.get(m.symbol) orelse data.get("s") orelse .{ .string = "" }, null) orelse "";
                ticker.symbol = try self.allocator.dupe(u8, if (symbol_field.len > 0) symbol_field else "BTC/USDC");

                // Parse price data using Hyperliquid's field names
                ticker.last = parser.getFloat(data.get(m.last) orelse data.get(HyperliquidFieldNames.LAST_PRICE) orelse .{ .float = 0 }, 0);
                ticker.high = parser.getFloat(data.get(m.high) orelse data.get(HyperliquidFieldNames.HIGH_24H) orelse .{ .float = 0 }, 0);
                ticker.low = parser.getFloat(data.get(m.low) orelse data.get(HyperliquidFieldNames.LOW_24H) orelse .{ .float = 0 }, 0);

                // Parse bid/ask using Hyperliquid's bidPx/bidSz format
                ticker.bid = parser.getFloat(data.get("bidPx") orelse data.get("bid") orelse .{ .float = 0 }, 0);
                ticker.ask = parser.getFloat(data.get("askPx") orelse data.get("ask") orelse .{ .float = 0 }, 0);

                // Parse volume
                ticker.baseVolume = parser.getFloat(data.get(m.base_volume) orelse data.get(HyperliquidFieldNames.VOLUME_24H) orelse .{ .float = 0 }, 0);

                // Parse timestamp (Hyperliquid uses "time")
                const ts_field = data.get(m.timestamp) orelse data.get(HyperliquidFieldNames.TIMESTAMP) orelse .{ .integer = std.time.milliTimestamp() };
                ticker.timestamp = self.base.parseTimestamp(ts_field, std.time.milliTimestamp());
            }
        }

        return ticker;
    }
    
    fn parseOrderBook(self: *Hyperliquid, json_data: []const u8) !models.OrderBook {
        const json = @import("../utils/json.zig");
        var parser = json.JsonParser.init(self.allocator);

        const parsed = try parser.parse(json_data);
        const root = parsed.value;

        var orderbook = try models.OrderBook.init(self.allocator);

        // Use Hyperliquid-specific field mappings
        const m = &self.base.field_mapping;

        if (parser.hasField(root, "success") and parser.getBool(root.get("success") orelse .{ .bool = false }, false)) {
            if (parser.hasField(root, "data")) {
                const data = root.get("data") orelse return orderbook;

                // Parse symbol (Hyperliquid uses "s" for symbol)
                const symbol_field = parser.getString(data.get(m.symbol) orelse data.get("s") orelse .{ .string = "" }, null) orelse "";
                orderbook.symbol = try self.allocator.dupe(u8, if (symbol_field.len > 0) symbol_field else "BTC/USDC");

                // Parse timestamp (Hyperliquid uses "time")
                const ts_field = data.get(m.timestamp) orelse data.get(HyperliquidFieldNames.TIMESTAMP) orelse .{ .integer = std.time.milliTimestamp() };
                orderbook.timestamp = self.base.parseTimestamp(ts_field, std.time.milliTimestamp());
                orderbook.datetime = try self.base.parseDatetime(self.allocator, orderbook.timestamp);

                // Parse bids (Hyperliquid returns array format: [price, size, ...])
                if (parser.hasField(data, "bids")) {
                    const bids_array = parser.getArray(data.get("bids") orelse .{ .array = .{ .items = &[_]std.json.Value{} } }, null) orelse return orderbook;

                    for (bids_array) |bid_data| {
                        const bid_array = parser.getArray(bid_data, null) orelse continue;
                        if (bid_array.len >= 2) {
                            // Hyperliquid uses "px" for price in individual order entries
                            const price = parser.getFloat(bid_array[0], 0);
                            // Hyperliquid uses "sz" for size in individual order entries
                            const amount = parser.getFloat(bid_array[1], 0);

                            var bid = models.OrderBookEntry{
                                .price = price,
                                .amount = amount,
                                .timestamp = orderbook.timestamp,
                            };
                            try orderbook.bids.append(bid);
                        }
                    }
                }

                // Parse asks (Hyperliquid returns array format: [price, size, ...])
                if (parser.hasField(data, "asks")) {
                    const asks_array = parser.getArray(data.get("asks") orelse .{ .array = .{ .items = &[_]std.json.Value{} } }, null) orelse return orderbook;

                    for (asks_array) |ask_data| {
                        const ask_array = parser.getArray(ask_data, null) orelse continue;
                        if (ask_array.len >= 2) {
                            const price = parser.getFloat(ask_array[0], 0);
                            const amount = parser.getFloat(ask_array[1], 0);

                            var ask = models.OrderBookEntry{
                                .price = price,
                                .amount = amount,
                                .timestamp = orderbook.timestamp,
                            };
                            try orderbook.asks.append(ask);
                        }
                    }
                }
            }
        }

        return orderbook;
    }
    
    fn parseOHLCV(self: *Hyperliquid, json_data: []const u8) ![]models.OHLCV {
        const json = @import("../utils/json.zig");
        var parser = json.JsonParser.init(self.allocator);
        
        const parsed = try parser.parse(json_data);
        const root = parsed.value;
        
        var ohlcv = std.ArrayList(models.OHLCV).init(self.allocator);
        defer ohlcv.deinit();
        
        if (parser.hasField(root, "success") and parser.getBool(root.get("success") orelse .{ .bool = false }, false)) {
            if (parser.hasField(root, "data")) {
                const data = root.get("data") orelse return try ohlcv.toOwnedSlice();
                
                if (parser.hasField(data, "candles")) {
                    const candles_array = parser.getArray(data.get("candles") orelse .{ .array = .{ .items = &[_]std.json.Value{} } }, null) orelse return try ohlcv.toOwnedSlice();
                    
                    for (candles_array) |candle_data| {
                        const candle_array = parser.getArray(candle_data, null) orelse continue;
                        if (candle_array.len >= 6) {
                            var candle = models.OHLCV{
                                .timestamp = parser.getInt(candle_array[0], 0),
                                .open = parser.getFloat(candle_array[1], 0),
                                .high = parser.getFloat(candle_array[2], 0),
                                .low = parser.getFloat(candle_array[3], 0),
                                .close = parser.getFloat(candle_array[4], 0),
                                .volume = parser.getFloat(candle_array[5], 0),
                            };
                            try ohlcv.append(candle);
                        }
                    }
                }
            }
        }
        
        return try ohlcv.toOwnedSlice();
    }
    
    fn parseTrades(self: *Hyperliquid, json_data: []const u8) ![]models.Trade {
        const json = @import("../utils/json.zig");
        var parser = json.JsonParser.init(self.allocator);

        const parsed = try parser.parse(json_data);
        const root = parsed.value;

        var trades = std.ArrayList(models.Trade).init(self.allocator);
        defer trades.deinit();

        // Use Hyperliquid-specific field mappings (px for price, sz for amount)
        const m = &self.base.field_mapping;

        if (parser.hasField(root, "success") and parser.getBool(root.get("success") orelse .{ .bool = false }, false)) {
            if (parser.hasField(root, "data")) {
                const data = root.get("data") orelse return try trades.toOwnedSlice();

                if (parser.hasField(data, "trades")) {
                    const trades_array = parser.getArray(data.get("trades") orelse .{ .array = .{ .items = &[_]std.json.Value{} } }, null) orelse return try trades.toOwnedSlice();

                    for (trades_array) |trade_data| {
                        var trade = try models.Trade.init(self.allocator);

                        // Parse trade ID (Hyperliquid uses "id" or "tradeId")
                        if (parser.hasField(trade_data, "id")) {
                            trade.id = try parser.getString(trade_data.get("id") orelse .{ .string = "" }, null) orelse "";
                        } else if (parser.hasField(trade_data, "tradeId")) {
                            trade.id = try parser.getString(trade_data.get("tradeId") orelse .{ .string = "" }, null) orelse "";
                        }

                        // Parse symbol (Hyperliquid uses "s" for symbol)
                        const symbol_field = parser.getString(trade_data.get(m.symbol) orelse .{ .string = "" }, null) orelse "";
                        trade.symbol = try self.allocator.dupe(u8, if (symbol_field.len > 0) symbol_field else "BTC/USDC");

                        // Parse side
                        const side_str = parser.getString(trade_data.get(m.side) orelse .{ .string = "" }, null) orelse "buy";
                        trade.side = if (std.mem.eql(u8, side_str, "buy")) .buy else .sell;

                        // Parse price using Hyperliquid's "px" field
                        trade.price = parser.getFloat(trade_data.get(m.price) orelse .{ .float = 0 }, 0);

                        // Parse amount/size using Hyperliquid's "sz" field
                        trade.amount = parser.getFloat(trade_data.get(m.amount) orelse .{ .float = 0 }, 0);

                        // Parse cost (price * amount)
                        trade.cost = trade.price * trade.amount;

                        // Parse timestamp (Hyperliquid uses "time" or "timestamp")
                        const ts_field = trade_data.get(m.timestamp) orelse trade_data.get("timestamp") orelse .{ .integer = std.time.milliTimestamp() };
                        trade.timestamp = self.base.parseTimestamp(ts_field, std.time.milliTimestamp());
                        trade.datetime = try self.base.parseDatetime(self.allocator, trade.timestamp);

                        try trades.append(trade);
                    }
                }
            }
        }

        return try trades.toOwnedSlice();
    }
    
    fn parseBalance(self: *Hyperliquid, json_data: []const u8) !models.Balance {
        const json = @import("../utils/json.zig");
        var parser = json.JsonParser.init(self.allocator);
        
        const parsed = try parser.parse(json_data);
        const root = parsed.value;
        
        var balance = try models.Balance.init(self.allocator);
        
        if (parser.hasField(root, "success") and parser.getBool(root.get("success") orelse .{ .bool = false }, false)) {
            if (parser.hasField(root, "data")) {
                const data = root.get("data") orelse return balance;
                
                if (parser.hasField(data, "balances")) {
                    const balances_obj = parser.getObject(data.get("balances") orelse .{ .object = .{} }, null) orelse return balance;
                    
                    var iter = balances_obj.iterator();
                    while (iter.next()) |entry| {
                        const currency = entry.key_ptr.*;
                        const balance_data = entry.value_ptr.*;
                        
                        var balance_entry = models.BalanceEntry{
                            .currency = try self.allocator.dupe(u8, currency),
                            .free = parser.getFloat(balance_data, 0),
                            .used = 0.0,
                            .total = parser.getFloat(balance_data, 0),
                        };
                        
                        try balance.entries.append(balance_entry);
                    }
                }
            }
        }
        
        return balance;
    }
    
    fn parseOrder(self: *Hyperliquid, json_data: []const u8) !models.Order {
        const json = @import("../utils/json.zig");
        var parser = json.JsonParser.init(self.allocator);

        const parsed = try parser.parse(json_data);
        const root = parsed.value;

        var order = try models.Order.init(self.allocator);

        // Use Hyperliquid-specific field mappings (px for price, sz for amount, oid for order ID)
        const m = &self.base.field_mapping;

        if (parser.hasField(root, "success") and parser.getBool(root.get("success") orelse .{ .bool = false }, false)) {
            if (parser.hasField(root, "data")) {
                const data = root.get("data") orelse return order;

                // Parse order ID (Hyperliquid uses "oid" or "orderId")
                const order_id = parser.getString(data.get(m.order_id) orelse data.get("orderId") orelse .{ .string = "" }, null) orelse "";
                order.id = try self.allocator.dupe(u8, if (order_id.len > 0) order_id else "");

                // Parse symbol (Hyperliquid uses "s" for symbol)
                const symbol_field = parser.getString(data.get(m.symbol) orelse .{ .string = "" }, null) orelse "";
                order.symbol = try self.allocator.dupe(u8, if (symbol_field.len > 0) symbol_field else "BTC/USDC");

                // Parse order type
                const type_str = parser.getString(data.get(m.type) orelse data.get("orderType") orelse .{ .string = "" }, null) orelse "limit";
                order.type = if (std.mem.eql(u8, type_str, "market")) .market else .limit;

                // Parse side
                const side_str = parser.getString(data.get(m.side) orelse .{ .string = "" }, null) orelse "buy";
                order.side = if (std.mem.eql(u8, side_str, "buy")) .buy else .sell;

                // Parse price using Hyperliquid's "px" field
                order.price = parser.getFloat(data.get(m.price) orelse .{ .float = 0 }, 0);

                // Parse amount/size using Hyperliquid's "sz" field
                order.amount = parser.getFloat(data.get(m.amount) orelse .{ .float = 0 }, 0);

                // Parse filled amount using Hyperliquid's "filledSz" field
                order.filled = parser.getFloat(data.get(m.filled) orelse data.get("filledSz") orelse .{ .float = 0 }, 0);

                // Parse remaining amount using Hyperliquid's "remainingSz" field
                order.remaining = parser.getFloat(data.get(m.remaining) orelse data.get("remainingSz") orelse .{ .float = 0 }, 0);

                // Parse status (Hyperliquid uses "status")
                const status_str = parser.getString(data.get(m.status) orelse .{ .string = "" }, null) orelse "open";
                order.status = if (std.mem.eql(u8, status_str, "open")) .open else if (std.mem.eql(u8, status_str, "closed")) .closed else if (std.mem.eql(u8, status_str, "canceled")) .canceled else .open;

                // Parse timestamp (Hyperliquid uses "time")
                const ts_field = data.get(m.timestamp) orelse data.get("time") orelse .{ .integer = std.time.milliTimestamp() };
                order.timestamp = self.base.parseTimestamp(ts_field, std.time.milliTimestamp());
                order.datetime = try self.base.parseDatetime(self.allocator, order.timestamp);
            }
        }

        return order;
    }
    
    // Hyperliquid-specific methods
    
    pub fn connectWallet(self: *Hyperliquid, wallet_address: []const u8, private_key: []const u8) !void {
        // Store wallet credentials for signing transactions
        // In a real implementation, this would connect to the wallet and verify credentials
        self.base.auth_config.wallet_address = try self.allocator.dupe(u8, wallet_address);
        self.base.auth_config.wallet_private_key = try self.allocator.dupe(u8, private_key);
        self.base.auth_config.wallet_connected = true;
    }
    
    pub fn getPerpetualInfo(self: *Hyperliquid, symbol: []const u8) !HyperliquidPerpetualInfo {
        // Build URL for perpetual info endpoint
        const url = try self.base.buildUrl("/perpetual");
        const params = try self.base.buildParams(.{
            .{ .key = "symbol", .value = symbol },
        });
        const response = try self.base.httpClient.get(url, params);
        defer response.deinit();
        
        // Parse the response
        const json = @import("../utils/json.zig");
        var parser = json.JsonParser.init(self.allocator);
        
        const parsed = try parser.parse(response.body);
        const root = parsed.value;
        
        if (parser.hasField(root, "success") and parser.getBool(root.get("success") orelse .{ .bool = false }, false)) {
            if (parser.hasField(root, "data")) {
                const data = root.get("data") orelse return .{
                    .symbol = try self.allocator.dupe(u8, symbol),
                    .funding_rate = 0.0001,
                    .open_interest = 1000.0,
                    .index_price = 50000.0,
                    .mark_price = 50001.0,
                };
                
                return .{
                    .symbol = try parser.getString(data.get("symbol") orelse .{ .string = symbol }, null) orelse try self.allocator.dupe(u8, symbol),
                    .funding_rate = parser.getFloat(data.get("fundingRate") orelse .{ .float = 0.0001 }, 0.0001),
                    .open_interest = parser.getFloat(data.get("openInterest") orelse .{ .float = 1000.0 }, 1000.0),
                    .index_price = parser.getFloat(data.get("indexPrice") orelse .{ .float = 50000.0 }, 50000.0),
                    .mark_price = parser.getFloat(data.get("markPrice") orelse .{ .float = 50001.0 }, 50001.0),
                };
            }
        }
        
        // Fallback to default values
        return .{
            .symbol = try self.allocator.dupe(u8, symbol),
            .funding_rate = 0.0001,
            .open_interest = 1000.0,
            .mark_price = 50001.0,
        };
    }
};

pub const HyperliquidPerpetualInfo = struct {
    symbol: []const u8,
    funding_rate: f64,
    open_interest: f64,
    index_price: f64,
    mark_price: f64,
    
    pub fn deinit(self: *HyperliquidPerpetualInfo, allocator: std.mem.Allocator) void {
        allocator.free(self.symbol);
    }
};