const std = @import("std");
const errors = @import("../../base/errors.zig");
const error_parser = @import("../../base/error_parser.zig");
const json = @import("../../utils/json.zig");

pub const CoinbaseErrorMapper = struct {
    pub fn mapError(allocator: std.mem.Allocator, json_val: json.JsonValue, status_code: u16) ?errors.CCXTError {
        // Coinbase uses "error" or "errors" field
        if (json_val.get("error")) |error_val| {
            return parseErrorObject(allocator, error_val, status_code);
        }
        
        if (json_val.getArray("errors")) |errors_array| {
            if (errors_array.items.len > 0) {
                return parseErrorObject(allocator, errors_array.items[0], status_code);
            }
        }
        
        // Check for message directly
        if (json_val.getString("message")) |message| {
            return parseErrorMessage(allocator, message, status_code);
        }
        
        return null;
    }
    
    fn parseErrorObject(allocator: std.mem.Allocator, error_val: json.JsonValue, status_code: u16) ?errors.CCXTError {
        var context = errors.ErrorContext.init(allocator);
        
        // Extract error details
        const error_type = error_val.getString("type") orelse
                          error_val.getString("code") orelse
                          "unknown";
        
        const message = error_val.getString("message") orelse
                       error_val.getString("detail") orelse
                       "Unknown error";
        
        context.message = allocator.dupe(u8, message) catch return null;
        
        // Map error type to CCXT error
        var mapped_error = errors.ExchangeError.ExchangeError;
        
        if (std.mem.eql(u8, error_type, "invalid_request") or
            std.mem.eql(u8, error_type, "unauthorized")) {
            mapped_error = errors.ExchangeError.AuthenticationError;
        } else if (std.mem.eql(u8, error_type, "not_found")) {
            mapped_error = errors.ExchangeError.OrderNotFound;
        } else if (std.mem.eql(u8, error_type, "invalid_order")) {
            mapped_error = errors.ExchangeError.InvalidOrder;
        } else if (std.mem.eql(u8, error_type, "insufficient_balance")) {
            mapped_error = errors.ExchangeError.InsufficientFunds;
        } else if (std.mem.indexOf(u8, error_type, "rate") != null) {
            mapped_error = errors.ExchangeError.RateLimitError;
        } else if (std.mem.indexOf(u8, message, "Insufficient funds") != null) {
            mapped_error = errors.ExchangeError.InsufficientFunds;
        } else if (std.mem.indexOf(u8, message, "Order not found") != null) {
            mapped_error = errors.ExchangeError.OrderNotFound;
        }
        
        return errors.CCXTError{
            .err = mapped_error,
            .context = &context,
            .retry_after = parseRetryAfter(status_code, error_val),
        };
    }
    
    fn parseErrorMessage(allocator: std.mem.Allocator, message: []const u8, status_code: u16) ?errors.CCXTError {
        var context = errors.ErrorContext.init(allocator);
        context.message = allocator.dupe(u8, message) catch return null;
        
        if (status_code == 429) {
            return errors.CCXTError{
                .err = errors.ExchangeError.RateLimitError,
                .context = &context,
                .retry_after = 60000, // Default 60 seconds
            };
        }
        
        var mapped_error = errors.ExchangeError.ExchangeError;
        
        if (std.mem.indexOf(u8, message, "invalid_request") != null or
            std.mem.indexOf(u8, message, "unauthorized") != null) {
            mapped_error = errors.ExchangeError.AuthenticationError;
        } else if (std.mem.indexOf(u8, message, "not_found") != null) {
            mapped_error = errors.ExchangeError.OrderNotFound;
        } else if (std.mem.indexOf(u8, message, "invalid_order") != null) {
            mapped_error = errors.ExchangeError.InvalidOrder;
        } else if (std.mem.indexOf(u8, message, "insufficient_balance") != null) {
            mapped_error = errors.ExchangeError.InsufficientFunds;
        }
        
        return errors.CCXTError{
            .err = mapped_error,
            .context = &context,
            .retry_after = null,
        };
    }
    
    fn parseRetryAfter(_: u16, error_val: json.JsonValue) ?u32 {
        // Check for retry_after in error details
        if (error_val.getInteger("retry_after")) |seconds| {
            return @as(u32, @intCast(seconds)) * 1000;
        }
        
        return null;
    }
    
    pub fn parseErrorResponse(
        allocator: std.mem.Allocator,
        status_code: u16,
        response_body: []const u8
    ) !errors.CCXTError {
        var parser = json.JsonParser.init(allocator);
        defer parser.deinit();
        
        const json_val = try parser.parse(response_body);
        defer json_val.deinit();
        
        if (mapError(allocator, json_val, status_code)) |mapped_error| {
            return mapped_error;
        }
        
        return error_parser.ErrorParser.parseError(
            allocator,
            status_code,
            response_body,
            null
        );
    }
};
