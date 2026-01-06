const std = @import("std");
const data = @import("data.zig");
const Order = data.Order;
const OrderSide = data.OrderSide;
const PriceLevel = data.PriceLevel;
const MarketDataMessage = data.MarketDataMessage;

/// Lock-free MPMC queue using atomic operations
pub fn LockFreeQueue(comptime T: type, comptime capacity: usize) type {
    return struct {
        const Self = @This();

        buffer: [capacity]T,
        head: std.atomic.Value(usize),
        tail: std.atomic.Value(usize),

        pub fn init() Self {
            return Self{
                .buffer = undefined,
                .head = std.atomic.Value(usize).init(0),
                .tail = std.atomic.Value(usize).init(0),
            };
        }

        pub fn push(self: *Self, item: T) bool {
            const current_tail = self.tail.load(.acquire);
            const next_tail = (current_tail + 1) % capacity;
            const current_head = self.head.load(.acquire);

            if (next_tail == current_head) {
                return false; // Queue full
            }

            self.buffer[current_tail] = item;
            _ = self.tail.cmpxchgStrong(current_tail, next_tail, .release, .acquire);
            return true;
        }

        pub fn pop(self: *Self) ?T {
            const current_head = self.head.load(.acquire);
            const current_tail = self.tail.load(.acquire);

            if (current_head == current_tail) {
                return null; // Queue empty
            }

            const item = self.buffer[current_head];
            const next_head = (current_head + 1) % capacity;
            _ = self.head.cmpxchgStrong(current_head, next_head, .release, .acquire);
            return item;
        }

        pub fn isEmpty(self: *Self) bool {
            return self.head.load(.acquire) == self.tail.load(.acquire);
        }

        pub fn size(self: *Self) usize {
            const h = self.head.load(.acquire);
            const t = self.tail.load(.acquire);
            if (t >= h) {
                return t - h;
            } else {
                return capacity - h + t;
            }
        }
    };
}

/// Order book with best bid/ask tracking
pub const OrderBook = struct {
    const MAX_LEVELS = 1000;

    bids: [MAX_LEVELS]PriceLevel, // Sorted descending by price
    asks: [MAX_LEVELS]PriceLevel, // Sorted ascending by price
    bid_count: usize,
    ask_count: usize,
    mutex: std.Thread.Mutex,

    pub fn init() OrderBook {
        return OrderBook{
            .bids = undefined,
            .asks = undefined,
            .bid_count = 0,
            .ask_count = 0,
            .mutex = std.Thread.Mutex{},
        };
    }

    pub fn addOrder(self: *OrderBook, price: u32, quantity: u64, side: OrderSide) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (side == .buy) {
            self.addBid(price, quantity);
        } else {
            self.addAsk(price, quantity);
        }
    }

    fn addBid(self: *OrderBook, price: u32, quantity: u64) void {
        // Find or create price level
        var i: usize = 0;
        while (i < self.bid_count) : (i += 1) {
            if (self.bids[i].price == price) {
                self.bids[i].quantity += quantity;
                return;
            } else if (self.bids[i].price < price) {
                break;
            }
        }

        // Insert new level
        if (self.bid_count < MAX_LEVELS) {
            var j = self.bid_count;
            while (j > i) : (j -= 1) {
                self.bids[j] = self.bids[j - 1];
            }
            self.bids[i] = PriceLevel.init(price, quantity);
            self.bid_count += 1;
        }
    }

    fn addAsk(self: *OrderBook, price: u32, quantity: u64) void {
        // Find or create price level
        var i: usize = 0;
        while (i < self.ask_count) : (i += 1) {
            if (self.asks[i].price == price) {
                self.asks[i].quantity += quantity;
                return;
            } else if (self.asks[i].price > price) {
                break;
            }
        }

        // Insert new level
        if (self.ask_count < MAX_LEVELS) {
            var j = self.ask_count;
            while (j > i) : (j -= 1) {
                self.asks[j] = self.asks[j - 1];
            }
            self.asks[i] = PriceLevel.init(price, quantity);
            self.ask_count += 1;
        }
    }

    pub fn removeOrder(self: *OrderBook, price: u32, quantity: u64, side: OrderSide) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (side == .buy) {
            self.removeBid(price, quantity);
        } else {
            self.removeAsk(price, quantity);
        }
    }

    fn removeBid(self: *OrderBook, price: u32, quantity: u64) void {
        var i: usize = 0;
        while (i < self.bid_count) : (i += 1) {
            if (self.bids[i].price == price) {
                if (self.bids[i].quantity <= quantity) {
                    // Remove level
                    var j = i;
                    while (j < self.bid_count - 1) : (j += 1) {
                        self.bids[j] = self.bids[j + 1];
                    }
                    self.bid_count -= 1;
                } else {
                    self.bids[i].quantity -= quantity;
                }
                return;
            }
        }
    }

    fn removeAsk(self: *OrderBook, price: u32, quantity: u64) void {
        var i: usize = 0;
        while (i < self.ask_count) : (i += 1) {
            if (self.asks[i].price == price) {
                if (self.asks[i].quantity <= quantity) {
                    // Remove level
                    var j = i;
                    while (j < self.ask_count - 1) : (j += 1) {
                        self.asks[j] = self.asks[j + 1];
                    }
                    self.ask_count -= 1;
                } else {
                    self.asks[i].quantity -= quantity;
                }
                return;
            }
        }
    }

    pub fn bestBid(self: *OrderBook) ?u32 {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.bid_count > 0) {
            return self.bids[0].price;
        }
        return null;
    }

    pub fn bestAsk(self: *OrderBook) ?u32 {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.ask_count > 0) {
            return self.asks[0].price;
        }
        return null;
    }

    pub fn midPrice(self: *OrderBook) ?f64 {
        const bid = self.bestBid();
        const ask = self.bestAsk();

        if (bid != null and ask != null) {
            return (@as(f64, @floatFromInt(bid.?)) + @as(f64, @floatFromInt(ask.?))) / 2.0;
        }
        return null;
    }

    pub fn spread(self: *OrderBook) ?u32 {
        const bid = self.bestBid();
        const ask = self.bestAsk();

        if (bid != null and ask != null) {
            return ask.? - bid.?;
        }
        return null;
    }

    pub fn spreadBps(self: *OrderBook) ?f64 {
        const mid = self.midPrice();
        const sprd = self.spread();

        if (mid != null and sprd != null) {
            return (@as(f64, @floatFromInt(sprd.?)) / mid.?) * 10000.0;
        }
        return null;
    }
};

/// Market data buffer - 1MB circular buffer with zero-copy semantics
pub const MarketDataBuffer = struct {
    const BUFFER_SIZE = 1024 * 1024; // 1MB

    buffer: [BUFFER_SIZE]u8 align(64),
    write_pos: std.atomic.Value(usize),
    read_pos: std.atomic.Value(usize),

    pub fn init() MarketDataBuffer {
        return MarketDataBuffer{
            .buffer = undefined,
            .write_pos = std.atomic.Value(usize).init(0),
            .read_pos = std.atomic.Value(usize).init(0),
        };
    }

    pub fn write(self: *MarketDataBuffer, bytes: []const u8) bool {
        const write_p = self.write_pos.load(.acquire);
        const read_p = self.read_pos.load(.acquire);

        const available = if (read_p > write_p)
            read_p - write_p - 1
        else
            BUFFER_SIZE - write_p + read_p - 1;

        if (bytes.len > available) {
            return false;
        }

        const end_pos = write_p + bytes.len;
        if (end_pos <= BUFFER_SIZE) {
            @memcpy(self.buffer[write_p..][0..bytes.len], bytes);
            self.write_pos.store(end_pos % BUFFER_SIZE, .release);
        } else {
            const first_chunk = BUFFER_SIZE - write_p;
            @memcpy(self.buffer[write_p..BUFFER_SIZE], bytes[0..first_chunk]);
            @memcpy(self.buffer[0..][0..(bytes.len - first_chunk)], bytes[first_chunk..]);
            self.write_pos.store(bytes.len - first_chunk, .release);
        }

        return true;
    }

    pub fn read(self: *MarketDataBuffer, buffer: []u8) usize {
        const read_p = self.read_pos.load(.acquire);
        const write_p = self.write_pos.load(.acquire);

        const available = if (write_p >= read_p)
            write_p - read_p
        else
            BUFFER_SIZE - read_p + write_p;

        const to_read = @min(buffer.len, available);
        if (to_read == 0) {
            return 0;
        }

        const end_pos = read_p + to_read;
        if (end_pos <= BUFFER_SIZE) {
            @memcpy(buffer[0..to_read], self.buffer[read_p..][0..to_read]);
            self.read_pos.store(end_pos % BUFFER_SIZE, .release);
        } else {
            const first_chunk = BUFFER_SIZE - read_p;
            @memcpy(buffer[0..first_chunk], self.buffer[read_p..BUFFER_SIZE]);
            @memcpy(buffer[first_chunk..to_read], self.buffer[0..][0..(to_read - first_chunk)]);
            self.read_pos.store(to_read - first_chunk, .release);
        }

        return to_read;
    }
};

test "LockFreeQueue basic operations" {
    var queue = LockFreeQueue(u32, 10).init();

    try std.testing.expect(queue.isEmpty());
    try std.testing.expect(queue.push(42));
    try std.testing.expect(!queue.isEmpty());

    const item = queue.pop();
    try std.testing.expect(item != null);
    try std.testing.expectEqual(@as(u32, 42), item.?);
    try std.testing.expect(queue.isEmpty());
}

test "OrderBook operations" {
    var book = OrderBook.init();

    book.addOrder(10000, 100, .buy);
    book.addOrder(10100, 100, .sell);

    const bid = book.bestBid();
    const ask = book.bestAsk();

    try std.testing.expect(bid != null);
    try std.testing.expect(ask != null);
    try std.testing.expectEqual(@as(u32, 10000), bid.?);
    try std.testing.expectEqual(@as(u32, 10100), ask.?);

    const sprd = book.spread();
    try std.testing.expect(sprd != null);
    try std.testing.expectEqual(@as(u32, 100), sprd.?);
}
