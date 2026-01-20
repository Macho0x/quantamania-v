const std = @import("std");
const errors = @import("../../base/errors.zig");
const error_parser = @import("../../base/error_parser.zig");
const json = @import("../../utils/json.zig");

pub const HuobiErrorMapper = struct {
    pub const MAPPINGS = [_]error_parser.ExchangeErrorMapper.ErrorMapping{
        .{ .error_code = "invalid-api-key", .ccxt_error = errors.ExchangeError.AuthenticationError },
        .{ .error_code = "api-key-invalid", .ccxt_error = errors.ExchangeError.AuthenticationError },
        .{ .error_code = "signature-not-valid", .ccxt_error = errors.ExchangeError.AuthenticationError },
        .{ .error_code = "signature-invalid", .ccxt_error = errors.ExchangeError.AuthenticationError },
        .{ .error_code = "order-not-found", .ccxt_error = errors.ExchangeError.OrderNotFound },
        .{ .error_code = "order-Not-found", .ccxt_error = errors.ExchangeError.OrderNotFound },
        .{ .error_code = "insufficient-balance", .ccxt_error = errors.ExchangeError.InsufficientFunds },
        .{ .error_code = "account-frozen-insufficient-balance", .ccxt_error = errors.ExchangeError.InsufficientFunds },
        .{ .error_code = "too-many-requests", .ccxt_error = errors.ExchangeError.RateLimitError },
        .{ .error_code = "rate-too-many-requests", .ccxt_error = errors.ExchangeError.RateLimitError },
        .{ .error_code = "api-signature-not-valid", .ccxt_error = errors.ExchangeError.AuthenticationError },
    };
    
    pub fn mapError(allocator: std.mem.Allocator, json_val: json.JsonValue) ?errors.CCXTError {
        // Huobi returns "status" and "err-code" or "err_code"
        const status = json_val.getString("status") orelse "ok";
        
        if (std.mem.eql(u8, status, "error")) {
            const code = json_val.getString("err-code") orelse 
                           json_val.getString("err_code") orelse
                           json_val.getString("err-code");
            
            const message = json_val.getString("err-msg") orelse 
                             json_val.getString("err_msg") orelse
                             json_val.getString("err-msg") orelse
                             "Unknown error";
            
            if (code) |error_code| {
                return createCCXTError(allocator, error_code, message);
            } else {
                // No error code, try to map from message
                return parseErrorMessage(allocator, message);
            }
        }
        
        // Alternative: "code" field for errors
        if (json_val.getInteger("code")) |code_int| {
            if (code_int != 200) { // 200 is success
                const code_str = std.fmt.allocPrint(allocator, "{d}", .{code_int}) catch return null;
                defer allocator.free(code_str);
                
                const message = json_val.getString("message") orelse
                                 json_val.getString("msg") orelse
                                 "Unknown error";
                
                return createCCXTError(allocator, code_str, message);
            }
        }
        
        return null;
    }
    
    fn createCCXTError(
        allocator: std.mem.Allocator, 
        code_str: []const u8, 
        message: []const u8
    ) ?errors.CCXTError {
        if (error_parser.ExchangeErrorMapper.mapErrorCode(&MAPPINGS, code_str)) |ccxt_error| {
            var context = errors.ErrorContext.init(allocator);
            context.message = allocator.dupe(u8, message) catch return null;
            
            return errors.CCXTError{
                .err = ccxt_error,
                .context = &context,
                .retry_after = null,
            };
        }
        
        return null;
    }
    
    fn parseErrorMessage(allocator: std.mem.Allocator, message: []const u8) ?errors.CCXTError {
        var context = errors.ErrorContext.init(allocator);
        context.message = allocator.dupe(u8, message) catch return null;
        
        var mapped_error = errors.ExchangeError.ExchangeError;
        
        if (std.mem.indexOf(u8, message, "invalid-api-key") != null or
            std.mem.indexOf(u8, message, "signature-not-valid") != null or
            std.mem.indexOf(u8, message, "api-key-invalid") != null) {
            mapped_error = errors.ExchangeError.AuthenticationError;
        } else if (std.mem.indexOf(u8, message, "order-not-found") != null or
                   std.mem.indexOf(u8, message, "order-Not-found") != null) {
            mapped_error = errors.ExchangeError.OrderNotFound;
        } else if (std.mem.indexOf(u8, message, "insufficient-balance") != null) {
            mapped_error = errors.ExchangeError.InsufficientFunds;
        } else if (std.mem.indexOf(u8, message, "too-many-requests") != null or
                   std.mem.indexOf(u8, message, "rate-too-many-requests") != null) {
            mapped_error = errors.ExchangeError.RateLimitError;
        }
        
        return errors.CCXTError{
            .err = mapped_error,
            .context = &context,
            .retry_after = null,
        };
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
