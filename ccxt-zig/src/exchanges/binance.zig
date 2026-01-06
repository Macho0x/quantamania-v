const std = @import("std");
const BaseExchange = @import("../base/exchange.zig").BaseExchange;
const ExchangeConfig = @import("../base/exchange.zig").ExchangeConfig;
const OrderBook = @import("../base/exchange.zig").OrderBook;
const auth = @import("../base/auth.zig");
const types = @import("../base/types.zig");
const Market = @import("../models/market.zig").Market;
const Ticker = @import("../models/ticker.zig").Ticker;
const Order = @import("../models/order.zig").Order;
const OrderType = @import("../models/order.zig").OrderType;
const OrderSide = @import("../models/order.zig").OrderSide;
const OrderStatus = @import("../models/order.zig").OrderStatus;
const Trade = @import("../models/trade.zig").Trade;
const OHLCV = @import("../models/ohlcv.zig").OHLCV;
const Balance = @import("../models/balance.zig").Balance;

pub const BinanceExchange = struct {
    base: BaseExchange,
    
    pub fn create(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) !*BinanceExchange {
        const config = ExchangeConfig{
            .apiUrl = "https://api.binance.com",
            .wsUrl = "wss://stream.binance.com:9443/ws",
            .testApiUrl = "https://testnet.binance.vision",
            .testWsUrl = "wss://testnet.binance.vision/ws",
            .rateLimit = 50, // 1200 requests per minute = 50ms per request
            .enableRateLimit = true,
            .timeout = 30000,
            .verbose = false,
        };
        
        const exchange = try allocator.create(BinanceExchange);
        exchange.* = .{
            .base = try BaseExchange.init(allocator, "binance", "Binance", config, auth_config),
        };
        
        return exchange;
    }
    
    pub fn destroy(self: *BinanceExchange) void {
        self.base.deinit();
        self.base.allocator.destroy(self);
    }
    
    pub fn fetchMarkets(self: *BinanceExchange) ![]Market {
        self.base.throttle();
        
        const url = try std.fmt.allocPrint(
            self.base.allocator,
            "{s}/api/v3/exchangeInfo",
            .{self.base.getApiUrl()},
        );
        defer self.base.allocator.free(url);
        
        const response = try self.base.http_client.get(url, null);
        defer {
            var mut_response = response;
            mut_response.deinit(self.base.allocator);
        }
        
        if (response.status != 200) {
            return error.ExchangeError;
        }
        
        const parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.base.allocator,
            response.body,
            .{},
        );
        defer parsed.deinit();
        
        const root = parsed.value.object;
        const symbols_array = root.get("symbols").?.array;
        
        var markets = try std.ArrayList(Market).initCapacity(self.base.allocator, symbols_array.items.len);
        errdefer {
            for (markets.items) |*market| {
                market.deinit(self.base.allocator);
            }
            markets.deinit();
        }
        
        for (symbols_array.items) |symbol_obj| {
            const symbol = symbol_obj.object;
            
            const status = symbol.get("status").?.string;
            const is_active = std.mem.eql(u8, status, "TRADING");
            
            const base_asset = symbol.get("baseAsset").?.string;
            const quote_asset = symbol.get("quoteAsset").?.string;
            const symbol_str = symbol.get("symbol").?.string;
            
            var market = Market{
                .id = try self.base.allocator.dupe(u8, symbol_str),
                .symbol = try std.fmt.allocPrint(self.base.allocator, "{s}/{s}", .{ base_asset, quote_asset }),
                .base = try self.base.allocator.dupe(u8, base_asset),
                .quote = try self.base.allocator.dupe(u8, quote_asset),
                .baseId = try self.base.allocator.dupe(u8, base_asset),
                .quoteId = try self.base.allocator.dupe(u8, quote_asset),
                .active = is_active,
                .spot = true,
                .margin = symbol.get("isMarginTradingAllowed").?.bool,
                .future = false,
                .swap = false,
                .option = false,
                .contract = false,
            };
            
            // Parse filters for limits and precision
            if (symbol.get("filters")) |filters| {
                for (filters.array.items) |filter_obj| {
                    const filter = filter_obj.object;
                    const filter_type = filter.get("filterType").?.string;
                    
                    if (std.mem.eql(u8, filter_type, "PRICE_FILTER")) {
                        if (filter.get("minPrice")) |min_price_val| {
                            const min_price = try std.fmt.parseFloat(f64, min_price_val.string);
                            market.limits.price.min = min_price;
                        }
                        if (filter.get("maxPrice")) |max_price_val| {
                            const max_price = try std.fmt.parseFloat(f64, max_price_val.string);
                            market.limits.price.max = max_price;
                        }
                    } else if (std.mem.eql(u8, filter_type, "LOT_SIZE")) {
                        if (filter.get("minQty")) |min_qty_val| {
                            const min_qty = try std.fmt.parseFloat(f64, min_qty_val.string);
                            market.limits.amount.min = min_qty;
                        }
                        if (filter.get("maxQty")) |max_qty_val| {
                            const max_qty = try std.fmt.parseFloat(f64, max_qty_val.string);
                            market.limits.amount.max = max_qty;
                        }
                    } else if (std.mem.eql(u8, filter_type, "MIN_NOTIONAL") or std.mem.eql(u8, filter_type, "NOTIONAL")) {
                        if (filter.get("minNotional")) |min_notional_val| {
                            const min_notional = try std.fmt.parseFloat(f64, min_notional_val.string);
                            market.limits.cost.min = min_notional;
                        }
                    }
                }
            }
            
            // Parse precision
            if (symbol.get("baseAssetPrecision")) |base_prec| {
                market.precision.base = @intCast(base_prec.integer);
            }
            if (symbol.get("quoteAssetPrecision")) |quote_prec| {
                market.precision.quote = @intCast(quote_prec.integer);
            }
            
            try markets.append(market);
        }
        
        // Cache the markets
        if (self.base.markets == null) {
            self.base.markets = std.StringHashMap(Market).init(self.base.allocator);
        }
        
        for (markets.items) |market| {
            const key = try self.base.allocator.dupe(u8, market.symbol);
            try self.base.markets.?.put(key, market);
        }
        
        self.base.last_markets_fetch = std.time.milliTimestamp();
        
        return try markets.toOwnedSlice();
    }
    
    pub fn fetchTicker(self: *BinanceExchange, symbol: []const u8) !Ticker {
        self.base.throttle();
        
        const binance_symbol = try self.symbolToBinance(symbol);
        defer self.base.allocator.free(binance_symbol);
        
        const url = try std.fmt.allocPrint(
            self.base.allocator,
            "{s}/api/v3/ticker/24hr?symbol={s}",
            .{ self.base.getApiUrl(), binance_symbol },
        );
        defer self.base.allocator.free(url);
        
        const response = try self.base.http_client.get(url, null);
        defer {
            var mut_response = response;
            mut_response.deinit(self.base.allocator);
        }
        
        if (response.status != 200) {
            return error.ExchangeError;
        }
        
        const parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.base.allocator,
            response.body,
            .{},
        );
        defer parsed.deinit();
        
        const ticker_obj = parsed.value.object;
        
        return Ticker{
            .symbol = try self.base.allocator.dupe(u8, symbol),
            .timestamp = std.time.milliTimestamp(),
            .high = try std.fmt.parseFloat(f64, ticker_obj.get("highPrice").?.string),
            .low = try std.fmt.parseFloat(f64, ticker_obj.get("lowPrice").?.string),
            .bid = try std.fmt.parseFloat(f64, ticker_obj.get("bidPrice").?.string),
            .bidVolume = try std.fmt.parseFloat(f64, ticker_obj.get("bidQty").?.string),
            .ask = try std.fmt.parseFloat(f64, ticker_obj.get("askPrice").?.string),
            .askVolume = try std.fmt.parseFloat(f64, ticker_obj.get("askQty").?.string),
            .last = try std.fmt.parseFloat(f64, ticker_obj.get("lastPrice").?.string),
            .open = try std.fmt.parseFloat(f64, ticker_obj.get("openPrice").?.string),
            .close = try std.fmt.parseFloat(f64, ticker_obj.get("lastPrice").?.string),
            .previousClose = try std.fmt.parseFloat(f64, ticker_obj.get("prevClosePrice").?.string),
            .baseVolume = try std.fmt.parseFloat(f64, ticker_obj.get("volume").?.string),
            .quoteVolume = try std.fmt.parseFloat(f64, ticker_obj.get("quoteVolume").?.string),
            .percentage = if (ticker_obj.get("priceChangePercent")) |pct| 
                try std.fmt.parseFloat(f64, pct.string) else null,
            .vwap = if (ticker_obj.get("weightedAvgPrice")) |vwap| 
                try std.fmt.parseFloat(f64, vwap.string) else null,
        };
    }
    
    pub fn fetchOrderBook(self: *BinanceExchange, symbol: []const u8, limit: ?u32) !OrderBook {
        self.base.throttle();
        
        const binance_symbol = try self.symbolToBinance(symbol);
        defer self.base.allocator.free(binance_symbol);
        
        const limit_param = limit orelse 100;
        const url = try std.fmt.allocPrint(
            self.base.allocator,
            "{s}/api/v3/depth?symbol={s}&limit={d}",
            .{ self.base.getApiUrl(), binance_symbol, limit_param },
        );
        defer self.base.allocator.free(url);
        
        const response = try self.base.http_client.get(url, null);
        defer {
            var mut_response = response;
            mut_response.deinit(self.base.allocator);
        }
        
        if (response.status != 200) {
            return error.ExchangeError;
        }
        
        const parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.base.allocator,
            response.body,
            .{},
        );
        defer parsed.deinit();
        
        const depth = parsed.value.object;
        var order_book = try OrderBook.init(self.base.allocator, symbol);
        errdefer order_book.deinit(self.base.allocator);
        
        order_book.timestamp = std.time.milliTimestamp();
        
        if (depth.get("bids")) |bids_array| {
            for (bids_array.array.items) |bid_item| {
                const bid = bid_item.array;
                const price = try std.fmt.parseFloat(f64, bid.items[0].string);
                const amount = try std.fmt.parseFloat(f64, bid.items[1].string);
                try order_book.bids.append(.{ price, amount });
            }
        }
        
        if (depth.get("asks")) |asks_array| {
            for (asks_array.array.items) |ask_item| {
                const ask = ask_item.array;
                const price = try std.fmt.parseFloat(f64, ask.items[0].string);
                const amount = try std.fmt.parseFloat(f64, ask.items[1].string);
                try order_book.asks.append(.{ price, amount });
            }
        }
        
        return order_book;
    }
    
    pub fn fetchOHLCV(
        self: *BinanceExchange,
        symbol: []const u8,
        timeframe: types.TimeFrame,
        since: ?i64,
        limit: ?u32,
    ) ![]OHLCV {
        self.base.throttle();
        
        const binance_symbol = try self.symbolToBinance(symbol);
        defer self.base.allocator.free(binance_symbol);
        
        const interval = try self.timeframeToInterval(timeframe);
        const limit_param = limit orelse 500;
        
        var url: []u8 = undefined;
        if (since) |start_time| {
            url = try std.fmt.allocPrint(
                self.base.allocator,
                "{s}/api/v3/klines?symbol={s}&interval={s}&startTime={d}&limit={d}",
                .{ self.base.getApiUrl(), binance_symbol, interval, start_time, limit_param },
            );
        } else {
            url = try std.fmt.allocPrint(
                self.base.allocator,
                "{s}/api/v3/klines?symbol={s}&interval={s}&limit={d}",
                .{ self.base.getApiUrl(), binance_symbol, interval, limit_param },
            );
        }
        defer self.base.allocator.free(url);
        
        const response = try self.base.http_client.get(url, null);
        defer {
            var mut_response = response;
            mut_response.deinit(self.base.allocator);
        }
        
        if (response.status != 200) {
            return error.ExchangeError;
        }
        
        const parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.base.allocator,
            response.body,
            .{},
        );
        defer parsed.deinit();
        
        const klines_array = parsed.value.array;
        var ohlcv_list = try std.ArrayList(OHLCV).initCapacity(
            self.base.allocator,
            klines_array.items.len,
        );
        
        for (klines_array.items) |kline_item| {
            const kline = kline_item.array;
            
            const ohlcv = OHLCV{
                .timestamp = kline.items[0].integer,
                .open = try std.fmt.parseFloat(f64, kline.items[1].string),
                .high = try std.fmt.parseFloat(f64, kline.items[2].string),
                .low = try std.fmt.parseFloat(f64, kline.items[3].string),
                .close = try std.fmt.parseFloat(f64, kline.items[4].string),
                .volume = try std.fmt.parseFloat(f64, kline.items[5].string),
                .quoteVolume = try std.fmt.parseFloat(f64, kline.items[7].string),
                .count = @intCast(kline.items[8].integer),
                .takerBuyBaseVolume = try std.fmt.parseFloat(f64, kline.items[9].string),
                .takerBuyQuoteVolume = try std.fmt.parseFloat(f64, kline.items[10].string),
            };
            
            try ohlcv_list.append(ohlcv);
        }
        
        return try ohlcv_list.toOwnedSlice();
    }
    
    pub fn fetchTrades(
        self: *BinanceExchange,
        symbol: []const u8,
        _: ?i64,
        limit: ?u32,
    ) ![]Trade {
        self.base.throttle();
        
        const binance_symbol = try self.symbolToBinance(symbol);
        defer self.base.allocator.free(binance_symbol);
        
        const limit_param = limit orelse 500;
        const url = try std.fmt.allocPrint(
            self.base.allocator,
            "{s}/api/v3/trades?symbol={s}&limit={d}",
            .{ self.base.getApiUrl(), binance_symbol, limit_param },
        );
        defer self.base.allocator.free(url);
        
        const response = try self.base.http_client.get(url, null);
        defer {
            var mut_response = response;
            mut_response.deinit(self.base.allocator);
        }
        
        if (response.status != 200) {
            return error.ExchangeError;
        }
        
        const parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.base.allocator,
            response.body,
            .{},
        );
        defer parsed.deinit();
        
        const trades_array = parsed.value.array;
        var trades = try std.ArrayList(Trade).initCapacity(
            self.base.allocator,
            trades_array.items.len,
        );
        
        for (trades_array.items) |trade_obj| {
            const trade_data = trade_obj.object;
            
            const timestamp = trade_data.get("time").?.integer;
            const datetime_str = try self.formatTimestamp(timestamp);
            
            const trade = Trade{
                .id = try std.fmt.allocPrint(self.base.allocator, "{d}", .{trade_data.get("id").?.integer}),
                .timestamp = timestamp,
                .datetime = datetime_str,
                .symbol = try self.base.allocator.dupe(u8, symbol),
                .type = .spot,
                .side = try self.base.allocator.dupe(u8, if (trade_data.get("isBuyerMaker").?.bool) "sell" else "buy"),
                .price = try std.fmt.parseFloat(f64, trade_data.get("price").?.string),
                .amount = try std.fmt.parseFloat(f64, trade_data.get("qty").?.string),
                .cost = try std.fmt.parseFloat(f64, trade_data.get("quoteQty").?.string),
            };
            
            try trades.append(trade);
        }
        
        return try trades.toOwnedSlice();
    }
    
    pub fn fetchBalance(self: *BinanceExchange) !std.StringHashMap(Balance) {
        self.base.throttle();
        
        const timestamp = std.time.milliTimestamp();
        const url = try std.fmt.allocPrint(
            self.base.allocator,
            "{s}/api/v3/account?timestamp={d}",
            .{ self.base.getApiUrl(), timestamp },
        );
        defer self.base.allocator.free(url);
        
        var auth_manager = try auth.AuthManager.init(self.base.allocator, self.base.auth_config);
        defer auth_manager.deinit();
        
        const headers = try auth_manager.generateHeaders("binance", "GET", url, null);
        
        const response = try self.base.http_client.get(url, headers);
        defer {
            var mut_response = response;
            mut_response.deinit(self.base.allocator);
        }
        
        if (response.status != 200) {
            return error.AuthenticationError;
        }
        
        const parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.base.allocator,
            response.body,
            .{},
        );
        defer parsed.deinit();
        
        const account_obj = parsed.value.object;
        var balances = std.StringHashMap(Balance).init(self.base.allocator);
        
        if (account_obj.get("balances")) |balances_array| {
            for (balances_array.array.items) |balance_obj| {
                const balance_data = balance_obj.object;
                
                const currency = balance_data.get("asset").?.string;
                const free_str = balance_data.get("free").?.string;
                const locked_str = balance_data.get("locked").?.string;
                
                const free_val = try std.fmt.parseFloat(f64, free_str);
                const locked_val = try std.fmt.parseFloat(f64, locked_str);
                
                if (free_val == 0 and locked_val == 0) continue;
                
                const free = try types.Decimal.fromString(self.base.allocator, free_str);
                const used = try types.Decimal.fromString(self.base.allocator, locked_str);
                const total_val = free_val + locked_val;
                const total_str = try std.fmt.allocPrint(self.base.allocator, "{d}", .{total_val});
                defer self.base.allocator.free(total_str);
                const total = try types.Decimal.fromString(self.base.allocator, total_str);
                
                const balance = Balance.init(
                    try self.base.allocator.dupe(u8, currency),
                    free,
                    used,
                    total,
                    timestamp,
                );
                
                const key = try self.base.allocator.dupe(u8, currency);
                try balances.put(key, balance);
            }
        }
        
        return balances;
    }
    
    pub fn createOrder(
        self: *BinanceExchange,
        symbol: []const u8,
        order_type: []const u8,
        side: []const u8,
        amount: f64,
        price: ?f64,
    ) !Order {
        self.base.throttle();
        
        const binance_symbol = try self.symbolToBinance(symbol);
        defer self.base.allocator.free(binance_symbol);
        
        const timestamp = std.time.milliTimestamp();
        
        var params = std.ArrayList(u8).init(self.base.allocator);
        defer params.deinit();
        
        const writer = params.writer();
        try writer.print(
            "symbol={s}&side={s}&type={s}&quantity={d}&timestamp={d}",
            .{ binance_symbol, side, order_type, amount, timestamp },
        );
        
        if (price) |p| {
            try writer.print("&price={d}", .{p});
        }
        
        const url = try std.fmt.allocPrint(
            self.base.allocator,
            "{s}/api/v3/order?{s}",
            .{ self.base.getApiUrl(), params.items },
        );
        defer self.base.allocator.free(url);
        
        var auth_manager = try auth.AuthManager.init(self.base.allocator, self.base.auth_config);
        defer auth_manager.deinit();
        
        const headers = try auth_manager.generateHeaders("binance", "POST", url, null);
        
        const response = try self.base.http_client.post(url, headers, "");
        defer {
            var mut_response = response;
            mut_response.deinit(self.base.allocator);
        }
        
        if (response.status != 200) {
            return error.OrderError;
        }
        
        const parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.base.allocator,
            response.body,
            .{},
        );
        defer parsed.deinit();
        
        return try self.parseOrder(parsed.value.object, symbol);
    }
    
    pub fn cancelOrder(self: *BinanceExchange, order_id: []const u8, symbol: ?[]const u8) !Order {
        if (symbol == null) return error.InvalidOrder;
        
        self.base.throttle();
        
        const binance_symbol = try self.symbolToBinance(symbol.?);
        defer self.base.allocator.free(binance_symbol);
        
        const timestamp = std.time.milliTimestamp();
        const url = try std.fmt.allocPrint(
            self.base.allocator,
            "{s}/api/v3/order?symbol={s}&orderId={s}&timestamp={d}",
            .{ self.base.getApiUrl(), binance_symbol, order_id, timestamp },
        );
        defer self.base.allocator.free(url);
        
        var auth_manager = try auth.AuthManager.init(self.base.allocator, self.base.auth_config);
        defer auth_manager.deinit();
        
        const headers = try auth_manager.generateHeaders("binance", "DELETE", url, null);
        
        const response = try self.base.http_client.delete(url, headers);
        defer {
            var mut_response = response;
            mut_response.deinit(self.base.allocator);
        }
        
        if (response.status != 200) {
            return error.OrderError;
        }
        
        const parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.base.allocator,
            response.body,
            .{},
        );
        defer parsed.deinit();
        
        return try self.parseOrder(parsed.value.object, symbol.?);
    }
    
    pub fn fetchOrder(self: *BinanceExchange, order_id: []const u8, symbol: ?[]const u8) !Order {
        if (symbol == null) return error.InvalidOrder;
        
        self.base.throttle();
        
        const binance_symbol = try self.symbolToBinance(symbol.?);
        defer self.base.allocator.free(binance_symbol);
        
        const timestamp = std.time.milliTimestamp();
        const url = try std.fmt.allocPrint(
            self.base.allocator,
            "{s}/api/v3/order?symbol={s}&orderId={s}&timestamp={d}",
            .{ self.base.getApiUrl(), binance_symbol, order_id, timestamp },
        );
        defer self.base.allocator.free(url);
        
        var auth_manager = try auth.AuthManager.init(self.base.allocator, self.base.auth_config);
        defer auth_manager.deinit();
        
        const headers = try auth_manager.generateHeaders("binance", "GET", url, null);
        
        const response = try self.base.http_client.get(url, headers);
        defer {
            var mut_response = response;
            mut_response.deinit(self.base.allocator);
        }
        
        if (response.status != 200) {
            return error.OrderError;
        }
        
        const parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.base.allocator,
            response.body,
            .{},
        );
        defer parsed.deinit();
        
        return try self.parseOrder(parsed.value.object, symbol.?);
    }
    
    pub fn fetchOpenOrders(self: *BinanceExchange, symbol: ?[]const u8) ![]Order {
        self.base.throttle();
        
        const timestamp = std.time.milliTimestamp();
        
        var url: []u8 = undefined;
        if (symbol) |sym| {
            const binance_symbol = try self.symbolToBinance(sym);
            defer self.base.allocator.free(binance_symbol);
            
            url = try std.fmt.allocPrint(
                self.base.allocator,
                "{s}/api/v3/openOrders?symbol={s}&timestamp={d}",
                .{ self.base.getApiUrl(), binance_symbol, timestamp },
            );
        } else {
            url = try std.fmt.allocPrint(
                self.base.allocator,
                "{s}/api/v3/openOrders?timestamp={d}",
                .{ self.base.getApiUrl(), timestamp },
            );
        }
        defer self.base.allocator.free(url);
        
        var auth_manager = try auth.AuthManager.init(self.base.allocator, self.base.auth_config);
        defer auth_manager.deinit();
        
        const headers = try auth_manager.generateHeaders("binance", "GET", url, null);
        
        const response = try self.base.http_client.get(url, headers);
        defer {
            var mut_response = response;
            mut_response.deinit(self.base.allocator);
        }
        
        if (response.status != 200) {
            return error.OrderError;
        }
        
        const parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.base.allocator,
            response.body,
            .{},
        );
        defer parsed.deinit();
        
        const orders_array = parsed.value.array;
        var orders = try std.ArrayList(Order).initCapacity(
            self.base.allocator,
            orders_array.items.len,
        );
        
        for (orders_array.items) |order_obj| {
            const order_symbol = order_obj.object.get("symbol").?.string;
            const unified_symbol = try self.binanceToSymbol(order_symbol);
            defer self.base.allocator.free(unified_symbol);
            
            const order = try self.parseOrder(order_obj.object, unified_symbol);
            try orders.append(order);
        }
        
        return try orders.toOwnedSlice();
    }
    
    pub fn fetchClosedOrders(
        self: *BinanceExchange,
        symbol: ?[]const u8,
        since: ?i64,
        limit: ?u32,
    ) ![]Order {
        if (symbol == null) return error.InvalidOrder;
        
        self.base.throttle();
        
        const binance_symbol = try self.symbolToBinance(symbol.?);
        defer self.base.allocator.free(binance_symbol);
        
        const timestamp = std.time.milliTimestamp();
        const limit_param = limit orelse 500;
        
        var url: []u8 = undefined;
        if (since) |start_time| {
            url = try std.fmt.allocPrint(
                self.base.allocator,
                "{s}/api/v3/allOrders?symbol={s}&startTime={d}&limit={d}&timestamp={d}",
                .{ self.base.getApiUrl(), binance_symbol, start_time, limit_param, timestamp },
            );
        } else {
            url = try std.fmt.allocPrint(
                self.base.allocator,
                "{s}/api/v3/allOrders?symbol={s}&limit={d}&timestamp={d}",
                .{ self.base.getApiUrl(), binance_symbol, limit_param, timestamp },
            );
        }
        defer self.base.allocator.free(url);
        
        var auth_manager = try auth.AuthManager.init(self.base.allocator, self.base.auth_config);
        defer auth_manager.deinit();
        
        const headers = try auth_manager.generateHeaders("binance", "GET", url, null);
        
        const response = try self.base.http_client.get(url, headers);
        defer {
            var mut_response = response;
            mut_response.deinit(self.base.allocator);
        }
        
        if (response.status != 200) {
            return error.OrderError;
        }
        
        const parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.base.allocator,
            response.body,
            .{},
        );
        defer parsed.deinit();
        
        const orders_array = parsed.value.array;
        var orders = try std.ArrayList(Order).initCapacity(
            self.base.allocator,
            orders_array.items.len,
        );
        
        for (orders_array.items) |order_obj| {
            const order = try self.parseOrder(order_obj.object, symbol.?);
            if (order.status != .open) {
                try orders.append(order);
            }
        }
        
        return try orders.toOwnedSlice();
    }
    
    // Helper methods
    
    fn symbolToBinance(self: *BinanceExchange, symbol: []const u8) ![]u8 {
        // Convert BTC/USDT to BTCUSDT
        var result = std.ArrayList(u8).init(self.base.allocator);
        for (symbol) |c| {
            if (c != '/') {
                try result.append(c);
            }
        }
        return try result.toOwnedSlice();
    }
    
    fn binanceToSymbol(self: *BinanceExchange, binance_symbol: []const u8) ![]u8 {
        // Convert BTCUSDT to BTC/USDT (simplified - in production, use market lookup)
        const common_quotes = [_][]const u8{ "USDT", "BUSD", "USDC", "BTC", "ETH", "BNB" };
        
        for (common_quotes) |quote| {
            if (std.mem.endsWith(u8, binance_symbol, quote)) {
                const base = binance_symbol[0 .. binance_symbol.len - quote.len];
                return try std.fmt.allocPrint(self.base.allocator, "{s}/{s}", .{ base, quote });
            }
        }
        
        return try self.base.allocator.dupe(u8, binance_symbol);
    }
    
    fn timeframeToInterval(self: *BinanceExchange, timeframe: types.TimeFrame) ![]const u8 {
        _ = self;
        return switch (timeframe) {
            ._1m => "1m",
            ._5m => "5m",
            ._15m => "15m",
            ._30m => "30m",
            ._1h => "1h",
            ._2h => "2h",
            ._4h => "4h",
            ._6h => "6h",
            ._8h => "8h",
            ._12h => "12h",
            ._1d => "1d",
            ._3d => "3d",
            ._1w => "1w",
            ._2w => "2w",
            ._1M => "1M",
        };
    }
    
    fn formatTimestamp(self: *BinanceExchange, timestamp: i64) ![]u8 {
        return try std.fmt.allocPrint(self.base.allocator, "{d}", .{timestamp});
    }
    
    fn parseOrder(self: *BinanceExchange, order_obj: std.StringHashMap(std.json.Value), symbol: []const u8) !Order {
        const order_id_int = order_obj.get("orderId").?.integer;
        const timestamp = order_obj.get("time").?.integer;
        
        const status_str = order_obj.get("status").?.string;
        const status = if (std.mem.eql(u8, status_str, "NEW"))
            OrderStatus.open
        else if (std.mem.eql(u8, status_str, "FILLED"))
            OrderStatus.closed
        else if (std.mem.eql(u8, status_str, "CANCELED"))
            OrderStatus.canceled
        else if (std.mem.eql(u8, status_str, "EXPIRED"))
            OrderStatus.expired
        else if (std.mem.eql(u8, status_str, "REJECTED"))
            OrderStatus.rejected
        else
            OrderStatus.pending;
        
        const type_str = order_obj.get("type").?.string;
        const order_type = if (std.mem.eql(u8, type_str, "MARKET"))
            OrderType.market
        else if (std.mem.eql(u8, type_str, "LIMIT"))
            OrderType.limit
        else if (std.mem.eql(u8, type_str, "STOP_LOSS"))
            OrderType.stop
        else if (std.mem.eql(u8, type_str, "STOP_LOSS_LIMIT"))
            OrderType.stop_limit
        else if (std.mem.eql(u8, type_str, "TAKE_PROFIT"))
            OrderType.take_profit
        else if (std.mem.eql(u8, type_str, "TAKE_PROFIT_LIMIT"))
            OrderType.take_profit_limit
        else
            OrderType.limit;
        
        const side_str = order_obj.get("side").?.string;
        const side = if (std.mem.eql(u8, side_str, "BUY"))
            OrderSide.buy
        else
            OrderSide.sell;
        
        const price = try std.fmt.parseFloat(f64, order_obj.get("price").?.string);
        const orig_qty = try std.fmt.parseFloat(f64, order_obj.get("origQty").?.string);
        const executed_qty = try std.fmt.parseFloat(f64, order_obj.get("executedQty").?.string);
        const cummulative_quote_qty = try std.fmt.parseFloat(f64, order_obj.get("cummulativeQuoteQty").?.string);
        
        return Order{
            .id = try std.fmt.allocPrint(self.base.allocator, "{d}", .{order_id_int}),
            .clientOrderId = if (order_obj.get("clientOrderId")) |client_id|
                try self.base.allocator.dupe(u8, client_id.string)
            else
                null,
            .timestamp = timestamp,
            .datetime = try self.formatTimestamp(timestamp),
            .symbol = try self.base.allocator.dupe(u8, symbol),
            .type = order_type,
            .side = side,
            .price = price,
            .amount = orig_qty,
            .cost = cummulative_quote_qty,
            .filled = executed_qty,
            .remaining = orig_qty - executed_qty,
            .status = status,
            .average = if (executed_qty > 0) cummulative_quote_qty / executed_qty else null,
        };
    }
};
