const std = @import("std");
const errors = @import("../../base/errors.zig");
const error_parser = @import("../../base/error_parser.zig");
const json = @import("../../utils/json.zig");

pub const KrakenErrorMapper = struct {
    pub const MAPPINGS = [_]error_parser.ExchangeErrorMapper.ErrorMapping{
        .{ .error_code = "EAPI:Invalid key", .ccxt_error = errors.ExchangeError.AuthenticationError },
        .{ .error_code = "EAPI:Invalid signature", .ccxt_error = errors.ExchangeError.AuthenticationError },
        .{ .error_code = "EAPI:Rate limit exceeded", .ccxt_error = errors.ExchangeError.RateLimitError },
        .{ .error_code = "EOrder:Insufficient funds", .ccxt_error = errors.ExchangeError.InsufficientFunds },
        .{ .error_code = "EOrder:Order not found", .ccxt_error = errors.ExchangeError.OrderNotFound },
        .{ .error_code = "EService:Unavailable", .ccxt_error = errors.ExchangeError.ExchangeNotAvailable },
    };
    
    pub fn mapError(allocator: std.mem.Allocator, json_val: json.JsonValue) ?errors.CCXTError {
        // Kraken returns errors in an array under the "error" key
        if (json_val.getArray("error")) |error_array| {
            if (error_array.items.len > 0) {
                if (error_array.items[0].asString()) |error_str| {
                    return createCCXTError(allocator, error_str, null);
                }
            }
        }
        
        return null;
    }
    
    fn createCCXTError(
        allocator: std.mem.Allocator, 
        error_str: []const u8, 
        message: ?[]const u8
    ) ?errors.CCXTError {
        // First try exact mappings
        if (error_parser.ExchangeErrorMapper.mapErrorCode(&MAPPINGS, error_str)) |ccxt_error| {
            var context = errors.ErrorContext.init(allocator);
            context.message = allocator.dupe(u8, if (message) |msg| msg else error_str) catch return null;
            
            return errors.CCXTError{
                .err = ccxt_error,
                .context = &context,
                .retry_after = null,
            };
        }
        
        // Try partial matches for broader categories
        if (std.mem.indexOf(u8, error_str, "Insufficient funds") != null) {
            var context = errors.ErrorContext.init(allocator);
            context.message = allocator.dupe(u8, if (message) |msg| msg else error_str) catch return null;
            
            return errors.CCXTError{
                .err = errors.ExchangeError.InsufficientFunds,
                .context = &context,
                .retry_after = null,
            };
        }
        
        if (std.mem.indexOf(u8, error_str, "Order not found") != null) {
            var context = errors.ErrorContext.init(allocator);
            context.message = allocator.dupe(u8, if (message) |msg| msg else error_str) catch return null;
            
            return errors.CCXTError{
                .err = errors.ExchangeError.OrderNotFound,
                .context = &context,
                .retry_after = null,
            };
        }
        
        if (std.mem.indexOf(u8, error_str, "Rate limit") != null) {
            var context = errors.ErrorContext.init(allocator);
            context.message = allocator.dupe(u8, if (message) |msg| msg else error_str) catch return null;
            
            return errors.CCXTError{
                .err = errors.ExchangeError.RateLimitError,
                .context = &context,
                .retry_after = null,
            };
        }
        
        if (std.mem.indexOf(u8, error_str, "Invalid key") != null or
            std.mem.indexOf(u8, error_str, "Invalid signature") != null) {
            var context = errors.ErrorContext.init(allocator);
            context.message = allocator.dupe(u8, if (message) |msg| msg else error_str) catch return null;
            
            return errors.CCXTError{
                .err = errors.ExchangeError.AuthenticationError,
                .context = &context,
                .retry_after = null,
            };
        }
        
        if (std.mem.indexOf(u8, error_str, "Service:Unavailable") != null) {
            var context = errors.ErrorContext.init(allocator);
            context.message = allocator.dupe(u8, if (message) |msg| msg else error_str) catch return null;
            
            return errors.CCXTError{
                .err = errors.ExchangeError.ExchangeNotAvailable,
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
