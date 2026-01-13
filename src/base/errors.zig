const std = @import("std");

// Base error enums
pub const ExchangeError = error {
    NetworkError,
    AuthenticationError,
    OrderError,
    ExchangeError,
    RateLimitError,
    NotSupportedError,
    JsonError,
    TimeoutError,
    DNSError,
    SSLHandshakeError,
    ProxyError,
    PathNotFound,
    InvalidResponse,
    InvalidOrder,
    InsufficientFunds,
    OrderNotFilled,
    OrderNotFound,
    ExchangeNotAvailable,
    InsufficientNetworkFee,
};

// Detailed error context
pub const ErrorContext = struct {
    allocator: std.mem.Allocator,
    request_method: []const u8,
    request_url: []const u8,
    request_headers: ?[]const u8,
    request_body: ?[]const u8,
    response_status: u16,
    response_headers: ?[]const u8,
    response_body: ?[]const u8,
    timestamp: i64,
    message: []const u8,
    
    pub fn init(allocator: std.mem.Allocator) ErrorContext {
        return .{
            .allocator = allocator,
            .request_method = "",
            .request_url = "",
            .request_headers = null,
            .request_body = null,
            .response_status = 0,
            .response_headers = null,
            .response_body = null,
            .timestamp = std.time.milliTimestamp(),
            .message = "",
        };
    }
    
    pub fn deinit(self: *ErrorContext) void {
        if (self.request_headers) |h| self.allocator.free(h);
        if (self.request_body) |b| self.allocator.free(b);
        if (self.response_headers) |h| self.allocator.free(h);
        if (self.response_body) |b| self.allocator.free(b);
        self.allocator.free(self.message);
    }
};

// Error type wrapper with context
pub const CCXTError = struct {
    err: ExchangeError,
    context: ?*ErrorContext,
    retry_after: ?u32,
    
    pub fn message(self: *const CCXTError) []const u8 {
        if (self.context) |ctx| {
            return ctx.message;
        }
        return switch (self.err) {
            .NetworkError => "Network connection error",
            .AuthenticationError => "Authentication failed",
            .OrderError => "Order error",
            .ExchangeError => "Exchange API error",
            .RateLimitError => "Rate limit exceeded",
            .NotSupportedError => "Feature not supported",
            .JsonError => "JSON parsing error",
            .TimeoutError => "Request timeout",
            .DNSError => "DNS resolution failed",
            .SSLHandshakeError => "SSL handshake failed",
            .ProxyError => "Proxy connection error",
            .PathNotFound => "Resource not found",
            .InvalidResponse => "Invalid response from exchange",
            .InvalidOrder => "Invalid order parameters",
            .InsufficientFunds => "Insufficient funds",
            .OrderNotFilled => "Order not filled",
            .OrderNotFound => "Order not found",
            .ExchangeNotAvailable => "Exchange not available",
            .InsufficientNetworkFee => "Insufficient network fee",
            else => "Unknown error",
        };
    }
};

// Retry configuration
pub const RetryConfig = struct {
    max_attempts: u32 = 3,
    initial_delay_ms: u64 = 100,
    max_delay_ms: u64 = 10000,
    backoff_multiplier: f64 = 2.0,
    
    pub fn calculateDelay(self: *const RetryConfig, attempt: u32) u64 {
        if (attempt == 0) return 0;
        if (attempt >= self.max_attempts) return self.max_delay_ms;
        
        const delay = @as(u64, @intFromFloat(
            @as(f64, @floatFromInt(self.initial_delay_ms)) 
            * std.math.pow(f64, self.backoff_multiplier, @as(f64, @floatFromInt(attempt - 1)))
        ));
        
        return @min(delay, self.max_delay_ms);
    }
};

// Retry error classifier
pub const RetryClassifier = struct {
    pub fn shouldRetry(err: ExchangeError, http_status: u16) bool {
        if (http_status >= 500 and http_status < 600) {
            return true; // Server errors
        }
        
        if (http_status == 429 and http_status == 503) {
            return true; // Rate limit or service unavailable
        }
        
        return switch (err) {
            .NetworkError, .TimeoutError, .DNSError, .SSLHandshakeError, .ProxyError => true,
            .RateLimitError => true,
            .ExchangeNotAvailable => true,
            else => false,
        };
    }
    
    pub fn getRetryDelay(err: ExchangeError, http_status: u16) ?u32 {
        if (http_status == 429) {
            // Default rate limit delay: 60 seconds
            return 60000;
        }
        
        return switch (err) {
            .RateLimitError => 60000,
            .TimeoutError => 5000,
            .NetworkError => 2000,
            .DNSError => 3000,
            .SSLHandshakeError => 5000,
            .ProxyError => 3000,
            else => null,
        };
    }
};

// Error utility functions
pub fn newNetworkError(context: *ErrorContext) CCXTError {
    return CCXTError{
        .err = ExchangeError.NetworkError,
        .context = context,
        .retry_after = null,
    };
}

pub fn newAuthenticationError(context: *ErrorContext, message: []const u8) !CCXTError {
    const msg = try context.allocator.dupe(u8, message);
    context.message = msg;
    return CCXTError{
        .err = ExchangeError.AuthenticationError,
        .context = context,
        .retry_after = null,
    };
}

pub fn newRateLimitError(context: *ErrorContext, retry_after: u32) CCXTError {
    return CCXTError{
        .err = ExchangeError.RateLimitError,
        .context = context,
        .retry_after = retry_after,
    };
}

pub fn newJsonError(context: *ErrorContext, message: []const u8) !CCXTError {
    const msg = try context.allocator.dupe(u8, message);
    context.message = msg;
    return CCXTError{
        .err = ExchangeError.JsonError,
        .context = context,
        .retry_after = null,
    };
}

pub fn format(
    self: *const CCXTError,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = fmt;
    _ = options;
    try writer.print("CCXTError.{s}: {s}", .{ @tagName(self.err), self.message() });
    
    if (self.context) |ctx| {
        try writer.print(" | Request: {s} {s} | Status: {d}", .{
            ctx.request_method,
            ctx.request_url,
            ctx.response_status,
        });
    }
}