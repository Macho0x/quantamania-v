const std = @import("std");
const types = @import("../base/types.zig");

// Comprehensive precision and rounding utilities for all exchanges
pub const PrecisionMode = enum {
    decimal_places, // Number of decimal places (e.g., 8 for 0.00000001)
    significant_digits, // Number of significant digits (e.g., 6 for 123.456)
    tick_size, // Minimum price increment (e.g., 0.01)
};

pub const PrecisionUtils = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) PrecisionUtils {
        return .{ .allocator = allocator };
    }

    // Round to decimal places
    pub fn roundToDecimalPlaces(value: f64, places: u8) f64 {
        const multiplier = std.math.pow(f64, 10.0, @as(f64, @floatFromInt(places)));
        return @round(value * multiplier) / multiplier;
    }

    // Round to significant digits
    pub fn roundToSignificantDigits(value: f64, digits: u8) f64 {
        if (value == 0.0) return 0.0;

        const magnitude = @floor(@log10(@abs(value)));
        const multiplier = std.math.pow(f64, 10.0, @as(f64, @floatFromInt(digits)) - 1.0 - magnitude);
        return @round(value * multiplier) / multiplier;
    }

    // Round to tick size
    pub fn roundToTickSize(value: f64, tick_size: f64) f64 {
        if (tick_size == 0.0) return value;
        return @round(value / tick_size) * tick_size;
    }

    // Get decimal places from precision value
    pub fn getDecimalPlaces(precision: f64) u8 {
        if (precision >= 1.0) return 0;

        var places: u8 = 0;
        var value = precision;
        while (value < 1.0 and places < 18) : (places += 1) {
            value *= 10.0;
        }
        return places;
    }

    // Format price with precision
    pub fn formatPrice(self: *PrecisionUtils, price: f64, precision: ?u8, mode: PrecisionMode) ![]u8 {
        const prec = precision orelse 8;
        const rounded = switch (mode) {
            .decimal_places => roundToDecimalPlaces(price, prec),
            .significant_digits => roundToSignificantDigits(price, prec),
            .tick_size => price, // Already rounded
        };

        return std.fmt.allocPrint(self.allocator, "{d:.1$}", .{ rounded, prec });
    }

    // Format amount with precision
    pub fn formatAmount(self: *PrecisionUtils, amount: f64, precision: ?u8, mode: PrecisionMode) ![]u8 {
        const prec = precision orelse 8;
        const rounded = switch (mode) {
            .decimal_places => roundToDecimalPlaces(amount, prec),
            .significant_digits => roundToSignificantDigits(amount, prec),
            .tick_size => amount,
        };

        return std.fmt.allocPrint(self.allocator, "{d:.1$}", .{ rounded, prec });
    }

    // Truncate to decimal places (floor)
    pub fn truncateToDecimalPlaces(value: f64, places: u8) f64 {
        const multiplier = std.math.pow(f64, 10.0, @as(f64, @floatFromInt(places)));
        return @floor(value * multiplier) / multiplier;
    }

    // Ceil to decimal places
    pub fn ceilToDecimalPlaces(value: f64, places: u8) f64 {
        const multiplier = std.math.pow(f64, 10.0, @as(f64, @floatFromInt(places)));
        return @ceil(value * multiplier) / multiplier;
    }

    // Check if value respects precision
    pub fn checkPrecision(value: f64, precision: u8, mode: PrecisionMode) bool {
        const rounded = switch (mode) {
            .decimal_places => roundToDecimalPlaces(value, precision),
            .significant_digits => roundToSignificantDigits(value, precision),
            .tick_size => value,
        };
        return @abs(value - rounded) < 1e-10;
    }

    // Convert string to decimal with precision
    pub fn parseDecimal(self: *PrecisionUtils, str: []const u8, precision: ?u8) !f64 {
        const parsed = try std.fmt.parseFloat(f64, str);
        if (precision) |prec| {
            return roundToDecimalPlaces(parsed, prec);
        }
        return parsed;
    }

    // Get precision from string representation
    pub fn getPrecisionFromString(str: []const u8) u8 {
        if (std.mem.indexOf(u8, str, ".")) |dot_index| {
            return @intCast(str.len - dot_index - 1);
        }
        return 0;
    }

    // Calculate cost with precision (price * amount)
    pub fn calculateCost(price: f64, amount: f64, price_precision: ?u8, amount_precision: ?u8) f64 {
        const p = if (price_precision) |prec| roundToDecimalPlaces(price, prec) else price;
        const a = if (amount_precision) |prec| roundToDecimalPlaces(amount, prec) else amount;
        return p * a;
    }

    // Validate amount against market limits and precision
    pub fn validateAmount(
        amount: f64,
        min: ?f64,
        max: ?f64,
        precision: ?u8,
        mode: PrecisionMode,
    ) !void {
        if (amount <= 0.0) return error.InvalidAmount;

        if (min) |m| {
            if (amount < m) return error.AmountTooSmall;
        }

        if (max) |m| {
            if (amount > m) return error.AmountTooLarge;
        }

        if (precision) |prec| {
            if (!checkPrecision(amount, prec, mode)) {
                return error.InvalidPrecision;
            }
        }
    }

    // Validate price against market limits and precision
    pub fn validatePrice(
        price: f64,
        min: ?f64,
        max: ?f64,
        precision: ?u8,
        mode: PrecisionMode,
    ) !void {
        if (price <= 0.0) return error.InvalidPrice;

        if (min) |m| {
            if (price < m) return error.PriceTooLow;
        }

        if (max) |m| {
            if (price > m) return error.PriceTooHigh;
        }

        if (precision) |prec| {
            if (!checkPrecision(price, prec, mode)) {
                return error.InvalidPrecision;
            }
        }
    }

    // Validate cost (price * amount)
    pub fn validateCost(
        cost: f64,
        min: ?f64,
        max: ?f64,
    ) !void {
        if (cost <= 0.0) return error.InvalidCost;

        if (min) |m| {
            if (cost < m) return error.CostTooSmall;
        }

        if (max) |m| {
            if (cost > m) return error.CostTooLarge;
        }
    }

    // Format fee with precision
    pub fn formatFee(self: *PrecisionUtils, fee: f64, precision: ?u8) ![]u8 {
        const prec = precision orelse 8;
        const rounded = roundToDecimalPlaces(fee, prec);
        return std.fmt.allocPrint(self.allocator, "{d:.1$}", .{ rounded, prec });
    }

    // Calculate fee from cost and rate
    pub fn calculateFee(cost: f64, rate: f64, precision: ?u8) f64 {
        const fee = cost * rate;
        if (precision) |prec| {
            return roundToDecimalPlaces(fee, prec);
        }
        return fee;
    }

    // Convert precision mode between exchanges
    pub fn convertPrecision(value: f64, from_mode: PrecisionMode, to_mode: PrecisionMode, precision: u8) f64 {
        if (from_mode == to_mode) return value;

        return switch (to_mode) {
            .decimal_places => roundToDecimalPlaces(value, precision),
            .significant_digits => roundToSignificantDigits(value, precision),
            .tick_size => value,
        };
    }
};

// Exchange-specific precision configurations
pub const ExchangePrecisionConfig = struct {
    amount_mode: PrecisionMode = .decimal_places,
    price_mode: PrecisionMode = .decimal_places,
    default_amount_precision: u8 = 8,
    default_price_precision: u8 = 8,
    supports_tick_size: bool = false,

    // Common exchange configurations
    pub fn binance() ExchangePrecisionConfig {
        return .{
            .amount_mode = .decimal_places,
            .price_mode = .decimal_places,
            .default_amount_precision = 8,
            .default_price_precision = 8,
            .supports_tick_size = true,
        };
    }

    pub fn kraken() ExchangePrecisionConfig {
        return .{
            .amount_mode = .decimal_places,
            .price_mode = .decimal_places,
            .default_amount_precision = 8,
            .default_price_precision = 5,
            .supports_tick_size = false,
        };
    }

    pub fn coinbase() ExchangePrecisionConfig {
        return .{
            .amount_mode = .decimal_places,
            .price_mode = .decimal_places,
            .default_amount_precision = 8,
            .default_price_precision = 2,
            .supports_tick_size = false,
        };
    }

    pub fn bybit() ExchangePrecisionConfig {
        return .{
            .amount_mode = .decimal_places,
            .price_mode = .tick_size,
            .default_amount_precision = 8,
            .default_price_precision = 2,
            .supports_tick_size = true,
        };
    }

    pub fn okx() ExchangePrecisionConfig {
        return .{
            .amount_mode = .decimal_places,
            .price_mode = .decimal_places,
            .default_amount_precision = 8,
            .default_price_precision = 8,
            .supports_tick_size = true,
        };
    }

    pub fn gate() ExchangePrecisionConfig {
        return .{
            .amount_mode = .decimal_places,
            .price_mode = .decimal_places,
            .default_amount_precision = 8,
            .default_price_precision = 8,
            .supports_tick_size = false,
        };
    }

    pub fn huobi() ExchangePrecisionConfig {
        return .{
            .amount_mode = .decimal_places,
            .price_mode = .decimal_places,
            .default_amount_precision = 8,
            .default_price_precision = 8,
            .supports_tick_size = false,
        };
    }

    pub fn kucoin() ExchangePrecisionConfig {
        return .{
            .amount_mode = .decimal_places,
            .price_mode = .tick_size,
            .default_amount_precision = 8,
            .default_price_precision = 8,
            .supports_tick_size = true,
        };
    }

    pub fn bitfinex() ExchangePrecisionConfig {
        return .{
            .amount_mode = .significant_digits,
            .price_mode = .significant_digits,
            .default_amount_precision = 8,
            .default_price_precision = 5,
            .supports_tick_size = false,
        };
    }

    pub fn dex() ExchangePrecisionConfig {
        return .{
            .amount_mode = .decimal_places,
            .price_mode = .decimal_places,
            .default_amount_precision = 18, // DEX typically use 18 decimals
            .default_price_precision = 18,
            .supports_tick_size = false,
        };
    }
};

// Test helper functions
test "roundToDecimalPlaces" {
    try std.testing.expectEqual(@as(f64, 1.23), roundToDecimalPlaces(1.234567, 2));
    try std.testing.expectEqual(@as(f64, 1.2346), roundToDecimalPlaces(1.234567, 4));
    try std.testing.expectEqual(@as(f64, 0.00000001), roundToDecimalPlaces(0.000000012345, 8));
}

test "roundToSignificantDigits" {
    const result = roundToSignificantDigits(123.456789, 4);
    try std.testing.expectApproxEqAbs(@as(f64, 123.5), result, 0.01);
}

test "roundToTickSize" {
    try std.testing.expectEqual(@as(f64, 100.0), roundToTickSize(99.7, 5.0));
    try std.testing.expectEqual(@as(f64, 0.5), roundToTickSize(0.48, 0.1));
}

test "getDecimalPlaces" {
    try std.testing.expectEqual(@as(u8, 0), getDecimalPlaces(1.0));
    try std.testing.expectEqual(@as(u8, 2), getDecimalPlaces(0.01));
    try std.testing.expectEqual(@as(u8, 8), getDecimalPlaces(0.00000001));
}
