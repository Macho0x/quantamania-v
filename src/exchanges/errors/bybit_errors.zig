const std = @import("std");
const errors = @import("../../base/errors.zig");
const error_parser = @import("../../base/error_parser.zig");
const json = @import("../../utils/json.zig");

pub const BybitErrorMapper = struct {
    pub const MAPPINGS = [_]error_parser.ExchangeErrorMapper.ErrorMapping{
        .{ .error_code = "10001", .ccxt_error = errors.ExchangeError.InvalidOrder },
        .{ .error_code = "20001", .ccxt_error = errors.ExchangeError.OrderNotFound },
        .{ .error_code = "30001", .ccxt_error = errors.ExchangeError.InsufficientFunds },
        .{ .error_code = "110001", .ccxt_error = errors.ExchangeError.RateLimitError },
        .{ .error_code = "110002", .ccxt_error = errors.ExchangeError.RateLimitError },
        .{ .error_code = "110003", .ccxt_error = errors.ExchangeError.RateLimitError },
        .{ .error_code = "110004", .ccxt_error = errors.ExchangeError.RateLimitError },
        .{ .error_code = "110005", .ccxt_error = errors.ExchangeError.RateLimitError },
        .{ .error_code = "110006", .ccxt_error = errors.ExchangeError.RateLimitError },
        .{ .error_code = "110007", .ccxt_error = errors.ExchangeError.RateLimitError },
        .{ .error_code = "110008", .ccxt_error = errors.ExchangeError.RateLimitError },
        .{ .error_code = "110009", .ccxt_error = errors.ExchangeError.RateLimitError },
        .{ .error_code = "110010", .ccxt_error = errors.ExchangeError.RateLimitError },
        .{ .error_code = "110011", .ccxt_error = errors.ExchangeError.RateLimitError },
        .{ .error_code = "110012", .ccxt_error = errors.ExchangeError.RateLimitError },
        .{ .error_code = "110013", .ccxt_error = errors.ExchangeError.RateLimitError },
        .{ .error_code = "110014", .ccxt_error = errors.ExchangeError.RateLimitError },
        .{ .error_code = "110015", .ccxt_error = errors.ExchangeError.RateLimitError },
        .{ .error_code = "110016", .ccxt_error = errors.ExchangeError.RateLimitError },
        .{ .error_code = "110017", .ccxt_error = errors.ExchangeError.RateLimitError },
        .{ .error_code = "110018", .ccxt_error = errors.ExchangeError.RateLimitError },
        .{ .error_code = "110019", .ccxt_error = errors.ExchangeError.RateLimitError },
        .{ .error_code = "110020", .ccxt_error = errors.ExchangeError.RateLimitError },
        .{ .error_code = "110021", .ccxt_error = errors.ExchangeError.RateLimitError },
        .{ .error_code = "110022", .ccxt_error = errors.ExchangeError.RateLimitError },
        .{ .error_code = "110023", .ccxt_error = errors.ExchangeError.RateLimitError },
        .{ .error_code = "110024", .ccxt_error = errors.ExchangeError.RateLimitError },
        .{ .error_code = "110025", .ccxt_error = errors.ExchangeError.RateLimitError },
        .{ .error_code = "110026", .ccxt_error = errors.ExchangeError.RateLimitError },
        .{ .error_code = "110027", .ccxt_error = errors.ExchangeError.RateLimitError },
        .{ .error_code = "110028", .ccxt_error = errors.ExchangeError.RateLimitError },
        .{ .error_code = "110029", .ccxt_error = errors.ExchangeError.RateLimitError },
        .{ .error_code = "110030", .ccxt_error = errors.ExchangeError.RateLimitError },
    };
    
    pub fn mapError(allocator: std.mem.Allocator, json_val: json.JsonValue) ?errors.CCXTError {
        // Bybit returns retCode as error code
        if (json_val.getString("retCode")) |code_str| {
            const message = json_val.getString("retMsg");
            return createCCXTError(allocator, code_str, message);
        }
        
        if (json_val.getInteger("retCode")) |code_int| {
            const code_str = std.fmt.allocPrint(allocator, "{d}", .{code_int}) catch return null;
            defer allocator.free(code_str);
            
            const message = json_val.getString("retMsg");
            return createCCXTError(allocator, code_str, message);
        }
        
        // Alternative: ret_code
        if (json_val.getString("ret_code")) |code_str| {
            const message = json_val.getString("ret_msg") orelse json_val.getString("retMsg");
            return createCCXTError(allocator, code_str, message);
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
                context.message = allocator.dupe(u8, "Bybit API error") catch return null;
            }
            
            return errors.CCXTError{
                .err = ccxt_error,
                .context = &context,
                .retry_after = null,
            };
        }
        
        // Handle rate limit range 110001-110030
        if (code_str.len >= 6 and std.mem.startsWith(u8, code_str, "1100")) {
            if (std.fmt.parseInt(u32, code_str, 10)) |code_num| {
                if (code_num >= 110001 and code_num <= 110030) {
                    var context = errors.ErrorContext.init(allocator);
                    context.message = allocator.dupe(u8, message orelse "Rate limit exceeded") catch return null;
                    
                    return errors.CCXTError{
                        .err = errors.ExchangeError.RateLimitError,
                        .context = &context,
                        .retry_after = null,
                    };
                }
            } else |_| {}
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
