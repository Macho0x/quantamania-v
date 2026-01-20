const std = @import("std");
const errors = @import("errors.zig");
const json = @import("../utils/json.zig");

/// HTTP status code mappings to CCXT errors
pub const HttpStatusMapping = struct {
    pub fn mapStatusCode(status_code: u16) ?errors.ExchangeError {
        return switch (status_code) {
            400 => errors.ExchangeError.InvalidOrder,
            401 => errors.ExchangeError.AuthenticationError,
            403 => errors.ExchangeError.AuthenticationError,
            404 => errors.ExchangeError.PathNotFound,
            408 => errors.ExchangeError.TimeoutError,
            429 => errors.ExchangeError.RateLimitError,
            500 => errors.ExchangeError.ExchangeError,
            502 => errors.ExchangeError.NetworkError,
            503 => errors.ExchangeError.ExchangeNotAvailable,
            504 => errors.ExchangeError.TimeoutError,
            else => null,
        };
    }
};

/// Parse Retry-After header value
fn parseRetryAfter(header_value: ?[]const u8) ?u32 {
    if (header_value) |value| {
        // Try to parse as integer (seconds)
        if (std.fmt.parseInt(u32, value, 10)) |seconds| {
            return seconds * 1000; // Convert to milliseconds
        } else |_| {
            // Try to parse as HTTP-date (fallback to 60 seconds)
            return 60000;
        }
    }
    return null;
}

/// Generic response parsing for error detection
pub const ErrorParser = struct {
    pub fn parseError(
        allocator: std.mem.Allocator,
        status_code: u16,
        response_body: []const u8,
        headers: ?std.http.Headers,
    ) !errors.CCXTError {
        var context = errors.ErrorContext.init(allocator);
        context.response_status = status_code;
        
        if (response_body.len > 0) {
            context.response_body = try allocator.dupe(u8, response_body);
        }
        
        // Extract Retry-After header if present
        var retry_after: ?u32 = null;
        if (headers) |hdrs| {
            if (hdrs.get("retry-after")) |retry_header| {
                retry_after = parseRetryAfter(retry_header);
            }
        }
        
        // Try to parse JSON error response
        var parser = json.JsonParser.init(allocator);
        defer parser.deinit();
        
        if (parser.parse(response_body)) |json_val| {
            defer json_val.deinit();
            return parseJsonError(allocator, status_code, json_val, &context, retry_after);
        } else |_| {
            // Non-JSON response, use HTTP status code mapping
            if (HttpStatusMapping.mapStatusCode(status_code)) |mapped_error| {
                context.message = try allocator.dupe(u8, "HTTP error: ");
                return errors.CCXTError{
                    .err = mapped_error,
                    .context = &context,
                    .retry_after = retry_after,
                };
            }
            
            // Generic error based on status code
            if (status_code >= 400 and status_code < 500) {
                context.message = try allocator.dupe(u8, "Client error: ");
                return errors.CCXTError{
                    .err = errors.ExchangeError.InvalidResponse,
                    .context = &context,
                    .retry_after = retry_after,
                };
            } else if (status_code >= 500) {
                context.message = try allocator.dupe(u8, "Server error: ");
                return errors.CCXTError{
                    .err = errors.ExchangeError.ExchangeError,
                    .context = &context,
                    .retry_after = retry_after,
                };
            }
            
            context.message = try allocator.dupe(u8, "Unknown error");
            return errors.CCXTError{
                .err = errors.ExchangeError.ExchangeError,
                .context = &context,
                .retry_after = retry_after,
            };
        }
    }
    
    fn parseJsonError(
        allocator: std.mem.Allocator,
        status_code: u16,
        json_val: json.JsonValue,
        context: *errors.ErrorContext,
        retry_after: ?u32,
    ) !errors.CCXTError {
        _ = status_code;
        
        // Try to find error message in common locations
        const error_message = extractErrorMessage(allocator, json_val) orelse "Unknown error";
        context.message = error_message;
        
        // Try to extract error code
        const error_code = extractErrorCode(allocator, json_val);
        
        // Default mapping based on common patterns
        var mapped_error = errors.ExchangeError.ExchangeError;
        
        if (error_code) |code| {
            // Check for rate limit patterns
            if (std.mem.indexOf(u8, code, "rate") != null or 
                std.mem.indexOf(u8, code, "limit") != null or
                std.mem.indexOf(u8, code, "429") != null) {
                mapped_error = errors.ExchangeError.RateLimitError;
            }
            // Check for auth patterns
            else if (std.mem.indexOf(u8, code, "auth") != null or
                     std.mem.indexOf(u8, code, "key") != null or
                     std.mem.indexOf(u8, code, "sign") != null or
                     std.mem.indexOf(u8, code, "401") != null or
                     std.mem.indexOf(u8, code, "403") != null) {
                mapped_error = errors.ExchangeError.AuthenticationError;
            }
            // Check for order patterns
            else if (std.mem.indexOf(u8, code, "order") != null) {
                mapped_error = errors.ExchangeError.OrderError;
            }
            // Check for funds patterns
            else if (std.mem.indexOf(u8, code, "fund") != null or
                     std.mem.indexOf(u8, code, "balance") != null) {
                mapped_error = errors.ExchangeError.InsufficientFunds;
            }
            // Check for not found
            else if (std.mem.indexOf(u8, code, "not_found") != null or
                     std.mem.indexOf(u8, code, "404") != null) {
                mapped_error = errors.ExchangeError.OrderNotFound;
            }
        }
        
        return errors.CCXTError{
            .err = mapped_error,
            .context = context,
            .retry_after = retry_after,
        };
    }
    
    fn extractErrorMessage(allocator: std.mem.Allocator, json_val: json.JsonValue) ?[]const u8 {
        // Common error message locations across exchanges
        const paths = [_][]const []const u8{
            &.{"error", "message"},
            &.{"error", "msg"},
            &.{"msg"},
            &.{"message"},
            &.{"error"},
            &.{"error_message"},
            &.{"error_msg"},
            &.{"result", "error"},
            &.{"data", "error"},
        };
        
        for (paths) |path| {
            if (json_val.getPath(path)) |val| {
                if (val.asString()) |msg| {
                    return allocator.dupe(u8, msg) catch continue;
                }
            }
        }
        
        return null;
    }
    
    fn extractErrorCode(allocator: std.mem.Allocator, json_val: json.JsonValue) ?[]const u8 {
        // Common error code locations
        const paths = [_][]const []const u8{
            &.{"error", "code"},
            &.{"code"},
            &.{"error_code"},
            &.{"err_code"},
            &.{"errno"},
            &.{"error", "errno"},
            &.{"result", "error_code"},
        };
        
        for (paths) |path| {
            if (json_val.getPath(path)) |val| {
                if (val.asString()) |code| {
                    return allocator.dupe(u8, code) catch continue;
                }
                if (val.asInteger()) |code_int| {
                    const code_str = std.fmt.allocPrint(allocator, "{d}", .{code_int}) catch continue;
                    return code_str;
                }
            }
        }
        
        return null;
    }
    
    pub fn isSuccessResponse(status_code: u16, json_val: json.JsonValue) bool {
        // Check HTTP status first
        if (status_code < 200 or status_code >= 300) {
            return false;
        }
        
        // Some exchanges return success status but include error in body
        if (json_val.getString("success")) |success| {
            if (std.mem.eql(u8, success, "false") or std.mem.eql(u8, success, "0")) {
                return false;
            }
        }
        
        if (json_val.getInteger("ret_code")) |code| {
            if (code != 0) return false;
        }
        
        if (json_val.getInteger("retCode")) |code| {
            if (code != 0) return false;
        }
        
        if (json_val.getInteger("code")) |code| {
            if (code != 0 and code != 200 and code != 100000) return false;
        }
        
        // Check for error fields
        if (json_val.contains("error")) {
            if (json_val.get("error")) |err| {
                if (err.isNull() or err.isEmpty()) {
                    return true;
                }
                return false;
            }
        }
        
        if (json_val.getString("status")) |status| {
            if (std.mem.eql(u8, status, "error")) {
                return false;
            }
        }
        
        return true;
    }
};

/// Exchange-specific error mapper interface
pub const ExchangeErrorMapper = struct {
    pub const ErrorMapping = struct {
        error_code: []const u8,
        ccxt_error: errors.ExchangeError,
    };
    
    pub fn mapErrorCode(mappings: []const ErrorMapping, code: []const u8) ?errors.ExchangeError {
        for (mappings) |mapping| {
            if (std.mem.eql(u8, mapping.error_code, code)) {
                return mapping.ccxt_error;
            }
        }
        return null;
    }
    
    pub fn formatErrorMessage(allocator: std.mem.Allocator, 
                            base_message: []const u8,
                            request_id: ?[]const u8,
                            endpoint: ?[]const u8) ![]const u8 {
        var message = try allocator.alloc(u8, base_message.len + 256);
        var writer = std.io.fixedBufferStream(message).writer();
        
        try writer.writeAll(base_message);
        
        if (request_id) |id| {
            try writer.print(" | Request ID: {s}", .{id});
        }
        
        if (endpoint) |ep| {
            try writer.print(" | Endpoint: {s}", .{ep});
        }
        
        return message[0..@intCast(writer.context.pos)];
    }
};

test "HttpStatusMapping basic cases" {
    const testing = std.testing;
    
    try testing.expectEqual(errors.ExchangeError.AuthenticationError, HttpStatusMapping.mapStatusCode(401).?);
    try testing.expectEqual(errors.ExchangeError.RateLimitError, HttpStatusMapping.mapStatusCode(429).?);
    try testing.expectEqual(errors.ExchangeTimeoutError, HttpStatusMapping.mapStatusCode(503).?);
    try testing.expectEqual(errors.ExchangeError.NetworkError, HttpStatusMapping.mapStatusCode(500).?);
    try testing.expect(HttpStatusMapping.mapStatusCode(200) == null);
}

test "parseRetryAfter header parsing" {
    const testing = std.testing;
    
    try testing.expectEqual(@as(?u32, 30000), parseRetryAfter("30"));
    try testing.expectEqual(@as(?u32, 60000), parseRetryAfter("Mon, 20 Jan 2025 12:00:00 GMT"));
    try testing.expectEqual(@as(?u32, null), parseRetryAfter(null));
}
