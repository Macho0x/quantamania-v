const std = @import("std");
const errors = @import("errors.zig");
const crypto = @import("../utils/crypto.zig");

// HTTP Response structure
pub const HttpResponse = struct {
    status: u16,
    headers: std.StringHashMap([]const u8),
    body: []const u8,
    content_length: ?usize,
    content_encoding: ?[]const u8,
    request_duration_ms: u64,
    timing_start: u64,
    timing_end: u64,
    
    pub fn deinit(self: *HttpResponse, allocator: std.mem.Allocator) void {
        var iterator = self.headers.iterator();
        while (iterator.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            allocator.free(entry.value_ptr.*);
        }
        self.headers.deinit();
        allocator.free(self.body);
        if (self.content_encoding) |encoding| allocator.free(encoding);
    }
};

// HTTP Request structure
pub const HttpRequest = struct {
    method: []const u8,
    url: []const u8,
    headers: std.StringHashMap([]const u8),
    body: ?[]const u8,
    timeout_ms: u64,
    should_retry: bool,
    
    pub fn init(allocator: std.mem.Allocator, method: []const u8, url: []const u8) HttpRequest {
        return .{
            .method = method,
            .url = url,
            .headers = std.StringHashMap([]const u8).init(allocator),
            .body = null,
            .timeout_ms = 30000, // 30 seconds default
            .should_retry = true,
        };
    }
    
    pub fn deinit(self: *HttpRequest, allocator: std.mem.Allocator) void {
        var iterator = self.headers.iterator();
        while (iterator.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            allocator.free(entry.value_ptr.*);
        }
        self.headers.deinit();
        if (self.body) |body| allocator.free(body);
    }
    
    pub fn addHeader(self: *HttpRequest, allocator: std.mem.Allocator, key: []const u8, value: []const u8) !void {
        const key_copy = try allocator.dupe(u8, key);
        const value_copy = try allocator.dupe(u8, value);
        try self.headers.put(key_copy, value_copy);
    }
    
    pub fn setBody(self: *HttpRequest, allocator: std.mem.Allocator, body: []const u8) !void {
        if (self.body) |old_body| allocator.free(old_body);
        self.body = try allocator.dupe(u8, body);
    }
};

// Connection pool for HTTP keep-alive
pub const HttpConnectionPool = struct {
    allocator: std.mem.Allocator,
    connections: std.AutoHashMap([]const u8, std.ArrayList(*std.http.Client.Connection)),
    max_connections_per_host: usize,
    idle_timeout_ms: u64,
    
    pub fn init(allocator: std.mem.Allocator) HttpConnectionPool {
        return .{
            .allocator = allocator,
            .connections = std.AutoHashMap([]const u8, std.ArrayList(*std.http.Client.Connection)).init(allocator),
            .max_connections_per_host = 10,
            .idle_timeout_ms = 60000, // 1 minute
        };
    }
    
    pub fn deinit(self: *HttpConnectionPool) void {
        var iterator = self.connections.iterator();
        while (iterator.next()) |entry| {
            const host = entry.key_ptr.*;
            const pool = entry.value_ptr.*;
            
            for (pool.items) |conn| {
                conn.deinit();
            }
            
            pool.deinit();
            self.allocator.free(host);
        }
        
        self.connections.deinit();
    }
};

// HTTP Client with connection pooling and retry logic
pub const HttpClient = struct {
    allocator: std.mem.Allocator,
    http_client: std.http.Client,
    connection_pool: HttpConnectionPool,
    timeout_ms: u64,
    user_agent: []const u8,
    proxy_url: ?[]const u8,
    enable_compression: bool,
    enable_logging: bool,
    retry_config: errors.RetryConfig,
    
    pub fn init(allocator: std.mem.Allocator) !HttpClient {
        return .{
            .allocator = allocator,
            .http_client = std.http.Client{ .allocator = allocator },
            .connection_pool = HttpConnectionPool.init(allocator),
            .timeout_ms = 30000,
            .user_agent = "CCXT-Zig/0.1.0 (+https://github.com/ccxt/ccxt)",
            .proxy_url = null,
            .enable_compression = true,
            .enable_logging = false,
            .retry_config = errors.RetryConfig{
                .max_attempts = 3,
                .initial_delay_ms = 100,
                .max_delay_ms = 10000,
                .backoff_multiplier = 2.0,
            },
        };
    }
    
    pub fn deinit(self: *HttpClient) void {
        self.http_client.deinit();
        self.connection_pool.deinit();
        if (self.proxy_url) |url| self.allocator.free(url);
    }
    
    pub fn setTimeout(self: *HttpClient, timeout_ms: u64) void {
        self.timeout_ms = timeout_ms;
    }
    
    pub fn setUserAgent(self: *HttpClient, user_agent: []const u8) !void {
        self.user_agent = try self.allocator.dupe(u8, user_agent);
    }
    
    pub fn setProxy(self: *HttpClient, proxy_url: []const u8) !void {
        if (self.proxy_url) |url| self.allocator.free(url);
        self.proxy_url = try self.allocator.dupe(u8, proxy_url);
    }
    
    pub fn enableLogging(self: *HttpClient, enabled: bool) void {
        self.enable_logging = enabled;
    }
    
    pub fn request(
        self: *HttpClient,
        method: []const u8,
        url: []const u8,
        headers: ?std.StringHashMap([]const u8),
        body: ?[]const u8,
    ) !HttpResponse {
        return self.executeWithRetry(method, url, headers, body, 0);
    }
    
    fn executeWithRetry(
        self: *HttpClient,
        method: []const u8,
        url: []const u8,
        headers: ?std.StringHashMap([]const u8),
        body: ?[]const u8,
        attempt: u32,
    ) !HttpResponse {
        const start_time = std.time.milliTimestamp();
        
        if (self.enable_logging) {
            std.debug.print("HTTP {s} {s} (attempt {d})\n", .{ method, url, attempt + 1 });
            if (headers) |h| {
                var iterator = h.iterator();
                while (iterator.next()) |entry| {
                    std.debug.print("  {s}: {s}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
                }
            }
            if (body) |b| {
                std.debug.print("Body: {s}\n", .{b});
            }
        }
        
        const result = self.executeOnce(method, url, headers, body) catch |err| {
            const end_time = std.time.milliTimestamp();
            
            if (attempt < self.retry_config.max_attempts - 1 and 
                errors.RetryClassifier.shouldRetry(convertToExchangeError(err), 0)) {
                const delay_ms = self.retry_config.calculateDelay(attempt + 1);
                
                if (self.enable_logging) {
                    std.debug.print("Request failed, retrying in {d}ms: {any}\n", .{ delay_ms, err });
                }
                
                std.time.sleep(delay_ms * std.time.ns_per_ms);
                return self.executeWithRetry(method, url, headers, body, attempt + 1);
            }
            
            return err;
        };
        
        if (result.status >= 500 and result.status < 600) and 
           attempt < self.retry_config.max_attempts - 1 {
            const delay_ms = self.retry_config.calculateDelay(attempt + 1);
            
            if (self.enable_logging) {
                std.debug.print("Server error {d}, retrying in {d}ms\n", .{ result.status, delay_ms });
            }
            
            result.deinit(self.allocator);
            std.time.sleep(delay_ms * std.time.ns_per_ms);
            return self.executeWithRetry(method, url, headers, body, attempt + 1);
        }
        
        if (result.status == 429) and attempt < self.retry_config.max_attempts - 1 {
            const delay_ms = @max(self.retry_config.calculateDelay(attempt + 1), 60000); // Min 60s for rate limit
            
            if (self.enable_logging) {
                std.debug.print("Rate limited, retrying in {d}ms\n", .{delay_ms});
            }
            
            result.deinit(self.allocator);
            std.time.sleep(delay_ms * std.time.ns_per_ms);
            return self.executeWithRetry(method, url, headers, body, attempt + 1);
        }
        
        return result;
    }
    
    fn executeOnce(
        self: *HttpClient,
        method: []const u8,
        url: []const u8,
        headers: ?std.StringHashMap([]const u8),
        body: ?[]const u8,
    ) !HttpResponse {
        const uri = try std.Uri.parse(url);
        
        var req_headers = std.http.Headers{
            .allocator = self.allocator,
        };
        
        // Add default headers
        try req_headers.append("User-Agent", self.user_agent);
        try req_headers.append("Accept", "application/json, text/plain, */*");
        try req_headers.append("Accept-Encoding", "gzip, deflate, br");
        try req_headers.append("Connection", "keep-alive");
        
        if (body) |_| {
            try req_headers.append("Content-Type", "application/json");
        }
        
        // Add custom headers
        if (headers) |custom_headers| {
            var iterator = custom_headers.iterator();
            while (iterator.next()) |entry| {
                try req_headers.append(entry.key_ptr.*, entry.value_ptr.*);
            }
        }
        
        const payload = body orelse "";
        const http_method = convertMethod(method);
        
        var request = try self.http_client.open(http_method, uri, req_headers, .{ .connection = .keep_alive, .max_redirects = 5 });
        defer request.deinit();
        
        request.transfer_encoding = .chunked;
        try request.send();
        try request.finish();
        try request.wait();
        
        const response = request.response;
        const body_reader = request.reader();
        
        const body_content = try body_reader.readAllAlloc(self.allocator, 1024 * 1024 * 10); // 10MB max
        errdefer self.allocator.free(body_content);
        
        const decompressed_body = if (self.enable_compression and 
            std.mem.eql(u8, response.getContentEncoding() orelse "", "gzip")) 
        try crypto.decompressGzip(self.allocator, body_content) else body_content;
        
        if (self.enable_compression and 
            std.mem.eql(u8, response.getContentEncoding() orelse "", "gzip")) {
            self.allocator.free(body_content);
        }
        
        var response_headers = std.StringHashMap([]const u8).init(self.allocator);
        errdefer response_headers.deinit();
        
        var i: u16 = 0;
        while (i < response.headers.len) : (i += 1) {
            const header = response.headers.at(i);
            const key_copy = try self.allocator.dupe(u8, header.name);
            errdefer self.allocator.free(key_copy);
            
            const value_copy = try self.allocator.dupe(u8, header.value);
            errdefer self.allocator.free(value_copy);
            
            try response_headers.put(key_copy, value_copy);
        }
        
        const now = std.time.milliTimestamp();
        
        return HttpResponse{
            .status = @intFromEnum(response.status),
            .headers = response_headers,
            .body = decompressed_body,
            .content_length = response.content_length,
            .content_encoding = if (response.getContentEncoding()) |enc| 
                try self.allocator.dupe(u8, enc) else null,
            .request_duration_ms = now - start_time,
            .timing_start = 0, // Set to appropriate values if needed
            .timing_end = 0,
        };
    }
    
    // Convenience methods
    pub fn get(self: *HttpClient, url: []const u8, headers: ?std.StringHashMap([]const u8)) !HttpResponse {
        return self.request("GET", url, headers, null);
    }
    
    pub fn post(self: *HttpClient, url: []const u8, headers: ?std.StringHashMap([]const u8), body: []const u8) !HttpResponse {
        return self.request("POST", url, headers, body);
    }
    
    pub fn put(self: *HttpClient, url: []const u8, headers: ?std.StringHashMap([]const u8), body: []const u8) !HttpResponse {
        return self.request("PUT", url, headers, body);
    }
    
    pub fn delete(self: *HttpClient, url: []const u8, headers: ?std.StringHashMap([]const u8)) !HttpResponse {
        return self.request("DELETE", url, headers, null);
    }
    
    pub fn patch(self: *HttpClient, url: []const u8, headers: ?std.StringHashMap([]const u8), body: []const u8) !HttpResponse {
        return self.request("PATCH", url, headers, body);
    }
};

fn convertMethod(method: []const u8) std.http.Method {
    if (std.mem.eql(u8, method, "GET")) return .GET;
    if (std.mem.eql(u8, method, "POST")) return .POST;
    if (std.mem.eql(u8, method, "PUT")) return .PUT;
    if (std.mem.eql(u8, method, "DELETE")) return .DELETE;
    if (std.mem.eql(u8, method, "PATCH")) return .PATCH;
    if (std.mem.eql(u8, method, "HEAD")) return .HEAD;
    if (std.mem.eql(u8, method, "OPTIONS")) return .OPTIONS;
    return .GET;
}

fn convertToExchangeError(err: anyerror) errors.ExchangeError {
    return switch (err) {
        error.Timeout => errors.ExchangeError.TimeoutError,
        error.ConnectionRefused => errors.ExchangeError.NetworkError,
        error.NetworkUnreachable => errors.ExchangeError.NetworkError,
        error.ConnectionResetByPeer => errors.ExchangeError.NetworkError,
        error.NameResolutionFailure => errors.ExchangeError.DNSError,
        error.TlsHandshakeFailed => errors.ExchangeError.SSLHandshakeError,
        else => errors.ExchangeError.NetworkError,
    };
}