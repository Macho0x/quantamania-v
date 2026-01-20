const std = @import("std");
const errors = @import("../../base/errors.zig");
const error_parser = @import("../../base/error_parser.zig");
const json = @import("../../utils/json.zig");

pub const OkxErrorMapper = struct {
    pub const MAPPINGS = [_]error_parser.ExchangeErrorMapper.ErrorMapping{
        .{ .error_code = "50002", .ccxt_error = errors.ExchangeError.AuthenticationError },
        .{ .error_code = "50003", .ccxt_error = errors.ExchangeError.AuthenticationError },
        .{ .error_code = "58000", .ccxt_error = errors.ExchangeError.OrderNotFound },
        .{ .error_code = "58004", .ccxt_error = errors.ExchangeError.InsufficientFunds },
        .{ .error_code = "50011", .ccxt_error = errors.ExchangeError.ExchangeNotAvailable },
    };
    
    pub fn mapError(allocator: std.mem.Allocator, json_val: json.JsonValue) ?errors.CCXTError {
        // OKX returns error info in "data" array or object
        if (json_val.getArray("data")) |data_array| {
            if (data_array.items.len > 0) {
                if (data_array.items[0].getString("sCode")) |code| {
                    const message = data_array.items[0].getString("sMsg");
                    return createCCXTError(allocator, code, message);
                }
                
                if (data_array.items[0].getInteger("sCode")) |code_int| {
                    const code_str = std.fmt.allocPrint(allocator, "{d}", .{code_int}) catch return null;
                    defer allocator.free(code_str);
                    
                    const message = data_array.items[0].getString("sMsg");
                    return createCCXTError(allocator, code_str, message);
                }
            }
        }
        
        if (json_val.get("data")) |data_val| {
            if (data_val.getString("sCode")) |code| {
                const message = data_val.getString("sMsg");
                return createCCXTError(allocator, code, message);
            }
        }
        
        // Alternative: direct error method
        if (json_val.getString("code")) |code| {
            const message = json_val.getString("msg");
            return createCCXTError(allocator, code, message);
        }
        
        if (json_val.getInteger("code")) |code_int| {
            const code_str = std.fmt.allocPrint(allocator, "{d}", .{code_int}) catch return null;
            defer allocator.free(code_str);
            
            const message = json_val.getString("msg");
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
                context.message = allocator.dupe(u8, "OKX API error") catch return null;
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
