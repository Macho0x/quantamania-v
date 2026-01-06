const std = @import("std");
const data = @import("data.zig");
const MarketDataMessage = data.MarketDataMessage;
const OrderSide = data.OrderSide;

/// Parse binary market data message
/// Format: timestamp(8) | symbol(8) | price(4) | quantity(4) | side(1)
pub fn parseMarketData(bytes: []const u8) !MarketDataMessage {
    if (bytes.len < 25) {
        return error.InvalidMessageSize;
    }

    const timestamp64 = std.mem.readInt(i64, bytes[0..8], .little);
    const timestamp: i128 = @intCast(timestamp64);

    var symbol: [8]u8 = undefined;
    @memcpy(&symbol, bytes[8..16]);

    const price = std.mem.readInt(u32, bytes[16..20], .little);
    const quantity = std.mem.readInt(u32, bytes[20..24], .little);
    const side: OrderSide = if (bytes[24] == 0) .buy else .sell;

    return MarketDataMessage.init(timestamp, symbol, price, quantity, side);
}

/// Serialize market data message to binary format
pub fn serializeMarketData(msg: MarketDataMessage, buffer: []u8) !void {
    if (buffer.len < 25) {
        return error.BufferTooSmall;
    }

    const timestamp64: i64 = @intCast(msg.timestamp);
    std.mem.writeInt(i64, buffer[0..8], timestamp64, .little);
    @memcpy(buffer[8..16], &msg.symbol);
    std.mem.writeInt(u32, buffer[16..20], msg.price, .little);
    std.mem.writeInt(u32, buffer[20..24], msg.quantity, .little);
    buffer[24] = if (msg.side == .buy) 0 else 1;
}

/// FIX protocol message parser
pub const FixMessage = struct {
    msg_type: []const u8,
    fields: std.StringHashMap([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) FixMessage {
        return FixMessage{
            .msg_type = "",
            .fields = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *FixMessage) void {
        self.fields.deinit();
    }

    pub fn parse(allocator: std.mem.Allocator, raw: []const u8) !FixMessage {
        var msg = FixMessage.init(allocator);

        var it = std.mem.splitScalar(u8, raw, 0x01); // SOH delimiter
        while (it.next()) |field| {
            if (field.len == 0) continue;

            const eq_pos = std.mem.indexOfScalar(u8, field, '=') orelse continue;
            const tag = field[0..eq_pos];
            const value = field[eq_pos + 1 ..];

            if (std.mem.eql(u8, tag, "35")) {
                msg.msg_type = value;
            }

            try msg.fields.put(tag, value);
        }

        return msg;
    }

    pub fn getField(self: *FixMessage, tag: []const u8) ?[]const u8 {
        return self.fields.get(tag);
    }

    pub fn getOrderId(self: *FixMessage) ?u64 {
        const clord_id = self.getField("11") orelse return null;
        return std.fmt.parseInt(u64, clord_id, 10) catch null;
    }

    pub fn getExecutionPrice(self: *FixMessage) ?f64 {
        const price_str = self.getField("31") orelse return null;
        return std.fmt.parseFloat(f64, price_str) catch null;
    }

    pub fn getExecutionQty(self: *FixMessage) ?u64 {
        const qty_str = self.getField("32") orelse return null;
        return std.fmt.parseInt(u64, qty_str, 10) catch null;
    }
};

/// Get current timestamp in nanoseconds
pub fn nanoTimestamp() i128 {
    return std.time.nanoTimestamp();
}

/// Convert timestamp to microseconds
pub fn nanoToMicro(nano: i128) i128 {
    return @divFloor(nano, 1000);
}

/// Convert timestamp to milliseconds
pub fn nanoToMilli(nano: i128) i128 {
    return @divFloor(nano, 1_000_000);
}

/// Format symbol as fixed 8-byte array
pub fn formatSymbol(symbol: []const u8) [8]u8 {
    var result = [_]u8{' '} ** 8;
    const len = @min(symbol.len, 8);
    @memcpy(result[0..len], symbol[0..len]);
    return result;
}

test "parse market data message" {
    var buffer: [25]u8 = undefined;

    const symbol = formatSymbol("AAPL");
    const msg = MarketDataMessage.init(1234567890, symbol, 15000, 100, .buy);

    try serializeMarketData(msg, &buffer);

    const parsed = try parseMarketData(&buffer);
    try std.testing.expectEqual(msg.timestamp, parsed.timestamp);
    try std.testing.expectEqual(msg.price, parsed.price);
    try std.testing.expectEqual(msg.quantity, parsed.quantity);
    try std.testing.expectEqual(msg.side, parsed.side);
}

test "FIX message parsing" {
    const allocator = std.testing.allocator;

    const fix_msg = "8=FIX.4.2\x019=100\x0135=8\x0111=12345\x0131=150.50\x0132=100\x0110=000\x01";
    var parsed = try FixMessage.parse(allocator, fix_msg);
    defer parsed.deinit();

    try std.testing.expectEqualStrings("8", parsed.msg_type);

    const order_id = parsed.getOrderId();
    try std.testing.expect(order_id != null);
    try std.testing.expectEqual(@as(u64, 12345), order_id.?);
}

test "timestamp utilities" {
    const nano = nanoTimestamp();
    const micro = nanoToMicro(nano);
    const milli = nanoToMilli(nano);

    try std.testing.expect(micro < nano);
    try std.testing.expect(milli < micro);
}
