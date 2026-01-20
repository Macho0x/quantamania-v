const std = @import("std");
const errors = @import("../../base/errors.zig");
const error_parser = @import("../../base/error_parser.zig");
const json = @import("../../utils/json.zig");

pub const GateErrorMapper = struct {
    pub const MAPPINGS = [_]error_parser.ExchangeErrorMapper.ErrorMapping{
        .{ .error_code = "invalid_key", .ccxt_error = errors.ExchangeError.AuthenticationError },
        .{ .error_code = "key_ip_mismatch", .ccxt_error = errors.ExchangeError.AuthenticationError },
        .{ .error_code = "invalid_signature", .ccxt_error = errors.ExchangeError.AuthenticationError },
        .{ .error_code = "order_not_found", .ccxt_error = errors.ExchangeError.OrderNotFound },
        .{ .error_code = "insufficient_balance", .ccxt_error = errors.ExchangeError.InsufficientFunds },
        .{ .error_code = "too_many_requests", .ccxt_error = errors.ExchangeError.RateLimitError },
        .{ .error_code = "RATE_LIMIT_TOO_FAST", .ccxt_error = errors.ExchangeError.RateLimitError },
    };
    
    pub fn mapError(allocator: std.mem.Allocator, json_val: json.JsonValue) ?errors.CCXTError {
        // Gate.io returns "label" and "message"
        if (json_val.getString("label")) |label| {
            const message = json_val.getString("message");
            return createCCXTError(allocator, label, message);
        }
        
        // Alternative: error key with code
        if (json_val.getInteger("error") != null) {
            const message = json_val.getString("message") orelse 
                            json_val.getString("detail");
            
            // Try to extract error code from message
            if (message) |msg| {
                if (std.mem.indexOf(u8, msg, "too_many_requests") != null) {
                    return createCCXTError(allocator, "too_many_requests", message);
                }
                if (std.mem.indexOf(u8, msg, "invalid_key") != null) {
                    return createCCXTError(allocator, "invalid_key", message);
                }
                if (std.mem.indexOf(u8, msg, "order_not_found") != null) {
                    return createCCXTError(allocator, "order_not_found", message);
                }
                if (std.mem.indexOf(u8, msg, "insufficient_balance") != null) {
                    return createCCXTError(allocator, "insufficient_balance", message);
                }
            }
        }
        
        // Check for result object with error
        if (json_val.get("result")) |result_val| {
            if (result_val.getString("label")) |label| {
                const message = result_val.getString("message");
                return createCCXTError(allocator, label, message);
            }
        }
        
        return null;
    }
    
    fn createCCXTError(
        allocator: std.mem.Allocator, 
        code_str: []const u8, 
        message: ?[]const u8
    ) ?errors.CCXTError {
        if (error_parser.ExchangeErrorMapper.mapErrorCode(&MAPPINGS, code_str)) |ccxt_error| {
            var context = errors.ErrorContext.init(allocator);
            
            if (message) |msg| {
                context.message = allocator.dupe(u8, msg) catch return null;
            } else {
                context.message = allocator.dupe(u8, "Gate.io API error") catch return null;
            }
            
            return errors.CCXTError{
                .err = ccxt_error,
                .context = &context,
                .retry_after = null,
            };
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
        
        if (mapError(allocator, json_val)) |mapped_error| {
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
