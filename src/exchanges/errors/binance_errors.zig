const std = @import("std");
const errors = @import("../../base/errors.zig");
const error_parser = @import("../../base/error_parser.zig");
const json = @import("../../utils/json.zig");

pub const BinanceErrorMapper = struct {
    pub const MAPPINGS = [_]error_parser.ExchangeErrorMapper.ErrorMapping{
        .{ .error_code = "-1000", .ccxt_error = errors.ExchangeError.AuthenticationError },
        .{ .error_code = "-1001", .ccxt_error = errors.ExchangeError.AuthenticationError },
        .{ .error_code = "-1010", .ccxt_error = errors.ExchangeError.TimeoutError },
        .{ .error_code = "-1015", .ccxt_error = errors.ExchangeError.RateLimitError },
        .{ .error_code = "-2010", .ccxt_error = errors.ExchangeError.InsufficientFunds },
        .{ .error_code = "-2011", .ccxt_error = errors.ExchangeError.OrderNotFound },
        .{ .error_code = "-2014", .ccxt_error = errors.ExchangeError.AuthenticationError },
        .{ .error_code = "-2015", .ccxt_error = errors.ExchangeError.AuthenticationError },
    };
    
    pub fn mapError(allocator: std.mem.Allocator, json_val: json.JsonValue) ?errors.CCXTError {
        const code = json_val.getString("code") orelse {
            // Try alternative paths for error code
            if (json_val.getPath(&.{"error", "code"})) |code_val| {
                if (code_val.asInteger()) |code_int| {
                    const code_str = std.fmt.allocPrint(allocator, "{d}", .{code_int}) catch return null;
                    defer allocator.free(code_str);
                    
                    const message = json_val.getString("msg") orelse 
                        json_val.getPath(&.{"error", "msg", "message"}) orelse null;
                    
                    return createCCXTError(allocator, code_str, message);
                }
            }
            return null;
        };
        
        const message = json_val.getString("msg");
        return createCCXTError(allocator, code, message);
    }
    
    fn createCCXTError(
        allocator: std.mem.Allocator, 
        code: []const u8, 
        message: ?[]const u8
    ) ?errors.CCXTError {
        if (error_parser.ExchangeErrorMapper.mapErrorCode(&MAPPINGS, code)) |ccxt_error| {
            var context = errors.ErrorContext.init(allocator);
            
            if (message) |msg| {
                context.message = allocator.dupe(u8, msg) catch return null;
            } else {
                context.message = allocator.dupe(u8, "Binance API error") catch return null;
            }
            
            return errors.CCXTError{
                .err = ccxt_error,
                .context = &context,
                .retry_after = null,
            };
        }
        
        return null;
    }
    
    /// Parse Binance-specific error response format
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
        
        // Fallback to generic error parser
        return error_parser.ErrorParser.parseError(
            allocator,
            status_code,
            response_body,
            null
        );
    }
};
