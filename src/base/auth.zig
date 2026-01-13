const std = @import("std");
const crypto = @import("../utils/crypto.zig");
const url = @import("../utils/url.zig");
const time = @import("../utils/time.zig");

// Authentication configuration
pub const AuthConfig = struct {
    apiKey: ?[]const u8 = null,
    apiSecret: ?[]const u8 = null,
    passphrase: ?[]const u8 = null,
    uid: ?[]const u8 = null,
    password: ?[]const u8 = null,
    
    // Wallet-based authentication for DEX
    wallet_address: ?[]const u8 = null,
    wallet_private_key: ?[]const u8 = null,
    wallet_connected: bool = false,
    
    pub fn deinit(self: *AuthConfig, allocator: std.mem.Allocator) void {
        if (self.apiKey) |k| allocator.free(k);
        if (self.apiSecret) |s| allocator.free(s);
        if (self.passphrase) |p| allocator.free(p);
        if (self.uid) |u| allocator.free(u);
        if (self.password) |p| allocator.free(p);
        if (self.wallet_address) |w| allocator.free(w);
        if (self.wallet_private_key) |w| allocator.free(w);
    }
};

// OAuth 2.0 token handling
pub const OAuthToken = struct {
    access_token: []const u8,
    refresh_token: ?[]const u8,
    token_type: []const u8,
    expires_in: i64,
    scope: ?[]const u8,
    
    pub fn deinit(self: *OAuthToken, allocator: std.mem.Allocator) void {
        allocator.free(self.access_token);
        if (self.refresh_token) |t| allocator.free(t);
        allocator.free(self.token_type);
        if (self.scope) |s| allocator.free(s);
    }
};

pub const OauthManager = struct {
    allocator: std.mem.Allocator,
    client_id: []const u8,
    client_secret: []const u8,
    redirect_uri: []const u8,
    authorization_endpoint: []const u8,
    token_endpoint: []const u8,
    scope: []const u8,
    storage_path: ?[]const u8,
    
    pub fn init(allocator: std.mem.Allocator, client_id: []const u8, client_secret: []const u8, redirect_uri: []const u8) !OauthManager {
        return .{
            .allocator = allocator,
            .client_id = try allocator.dupe(u8, client_id),
            .client_secret = try allocator.dupe(u8, client_secret),
            .redirect_uri = try allocator.dupe(u8, redirect_uri),
            .authorization_endpoint = "",
            .token_endpoint = "",
            .scope = "",
            .storage_path = null,
        };
    }
    
    pub fn deinit(self: *OauthManager) void {
        if (self.client_id.len > 0) self.allocator.free(self.client_id);
        if (self.client_secret.len > 0) self.allocator.free(self.client_secret);
        if (self.redirect_uri.len > 0) self.allocator.free(self.redirect_uri);
        if (self.authorization_endpoint.len > 0) self.allocator.free(self.authorization_endpoint);
        if (self.token_endpoint.len > 0) self.allocator.free(self.token_endpoint);
        if (self.scope.len > 0) self.allocator.free(self.scope);
        if (self.storage_path) |p| self.allocator.free(p);
    }
    
    // Store token
    pub fn storeToken(self: *OauthManager, token: OAuthToken) !void {
        if (self.storage_path) |storage| _ = std.json.stringify(token, .{}, std.fs.cwd().createFile(storage, .{})?.writer());
    }
    
    // Load token
    pub fn loadToken(self: *OauthManager, token: *OAuthToken) !bool {
        if (self.storage_path) |storage| {
            const file = std.fs.cwd().openFile(storage, .{}) catch return false;
            defer file.close();
            
            const content = try file.readToEndAlloc(self.allocator, 1024 * 1024);
            defer self.allocator.free(content);
            
            // Parse token JSON
            return true;
        }
        return false;
    }
};

// Nonce generation with counter
pub const NonceGenerator = struct {
    last_timestamp: i64,
    counter: u32,
    
    pub fn init() NonceGenerator {
        return .{
            .last_timestamp = time.now(),
            .counter = 0,
        };
    }
    
    pub fn generate(self: *NonceGenerator) u64 {
        const now = time.now();
        
        if (now > self.last_timestamp) {
            self.last_timestamp = now;
            self.counter = 0;
        } else {
            self.counter += 1;
        }
        
        // Concatenate timestamp and counter: timestamp * 1000 + counter
        return @as(u64, @intCast(self.last_timestamp)) * 1000 + self.counter;
    }
    
    pub fn generateString(self: *NonceGenerator, allocator: std.mem.Allocator) ![]u8 {
        const nonce = self.generate();
        return std.fmt.allocPrint(allocator, "{d}", .{nonce});
    }
};

// Exchange-specific authentication handlers
pub const ExchangeAuth = struct {
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator) ExchangeAuth {
        return .{ .allocator = allocator };
    }
    
    // Binance authentication: X-MBX-APIKEY + HMAC-SHA256
    pub fn binanceAuth(self: *ExchangeAuth, config: AuthConfig, method: []const u8, url_all: []const u8, body: ?[]const u8, headers: *std.StringHashMap([]const u8)) !void {
        if (config.apiKey) |key| {
            try headers.put("X-MBX-APIKEY", key);
        }
        
        if (config.apiSecret) |secret| {
            const params = if (std.mem.eql(u8, method, "POST") or std.mem.eql(u8, method, "PUT")) body else url_all;
            const signature = try crypto.hmacSha256Hex(secret, params orelse "");
            
            try headers.put("X-MBX-SIGN", &signature);
        }
    }
    
    // Kraken authentication: API-Key + API-Sign (SHA256 of nonce+postdata)
    pub fn krakenAuth(self: *ExchangeAuth, config: AuthConfig, method: []const u8, url: []const u8, body: ?[]const u8, headers: *std.StringHashMap([]const u8)) !void {
        if (config.apiKey) |key| {
            try headers.put("API-Key", key);
        }
        
        if (config.apiSecret) |secret| {
            const nonce = try time.now().toString(self.allocator);
            defer self.allocator.free(nonce);
            
            var signed_data = std.ArrayList(u8).init(self.allocator);
            defer signed_data.deinit();
            
            try signed_data.appendSlice(nonce);
            if (body) |b| {
                try signed_data.appendSlice(b);
            }
            
            const signature = try crypto.Signer.hmacSha256Base64(self.allocator, secret, signed_data.items);
            defer self.allocator.free(signature);
            
            try headers.put("API-Sign", signature);
            try headers.put("API-Nonce", nonce);
        }
    }
    
    // Coinbase authentication: CB-ACCESS-KEY + CB-ACCESS-SIGN + CB-ACCESS-TIMESTAMP
    pub fn coinbaseAuth(self: *ExchangeAuth, config: AuthConfig, method: []const u8, url_all: []const u8, body: ?[]const u8, headers: *std.StringHashMap([]const u8)) !void {
        if (config.apiKey) |key| {
            try headers.put("CB-ACCESS-KEY", key);
        }
        
        const timestamp = try std.fmt.allocPrint(self.allocator, "{d}", .{time.now()});
        defer self.allocator.free(timestamp);
        try headers.put("CB-ACCESS-TIMESTAMP", timestamp);
        
        if (config.apiSecret) |secret| {
            // Message format: <timestamp><method><request_path><body>
            var message = std.ArrayList(u8).init(self.allocator);
            defer message.deinit();
            
            try message.appendSlice(timestamp);
            try message.appendSlice(method);
            
            const parsed_url = try url.Url.parse(url_all);
            defer self.allocator.free(parsed_url.path);
            
            try message.appendSlice(parsed_url.path);
            
            if (parsed_url.query) |q| {
                try message.append('?');
                try message.appendSlice(q);
            }
            
            if (body) |b| {
                try message.appendSlice(b);
            }
            
            const signature = try crypto.Signer.hmacSha256Base64(self.allocator, secret, message.items);
            defer self.allocator.free(signature);
            
            try headers.put("CB-ACCESS-SIGN", signature);
        }
    }
    
    // OKX authentication: OK-ACCESS-KEY + OK-ACCESS-SIGN + OK-ACCESS-TIMESTAMP
    pub fn okxAuth(self: *ExchangeAuth, config: AuthConfig, method: []const u8, url: []const u8, body: ?[]const u8, headers: *std.StringHashMap([]const u8)) !void {
        if (config.apiKey) |key| {
            try headers.put("OK-ACCESS-KEY", key);
        }
        
        const timestamp = try std.fmt.allocPrint(self.allocator, "{d}", .{time.now()});
        defer self.allocator.free(timestamp);
        try headers.put("OK-ACCESS-TIMESTAMP", timestamp);
        
        if (config.apiSecret) |secret| {
            var message = std.ArrayList(u8).init(self.allocator);
            defer message.deinit();
            
            try message.appendSlice(timestamp);
            try message.appendSlice(method);
            try message.appendSlice(url);
            
            if (body) |b| {
                try message.appendSlice(b);
            }
            
            const signature = try crypto.Signer.hmacSha256Base64(self.allocator, secret, message.items);
            defer self.allocator.free(signature);
            
            try headers.put("OK-ACCESS-SIGN", signature);
        }
        
        if (config.passphrase) |pass| {
            try headers.put("OK-ACCESS-PASSPHRASE", pass);
        }
    }
    
    // Bybit authentication: X-BAPI-API-KEY + X-BAPI-SIGN + X-BAPI-TIMESTAMP
    pub fn bybitAuth(self: *ExchangeAuth, config: AuthConfig, method: []const u8, url_all: []const u8, body: ?[]const u8, headers: *std.StringHashMap([]const u8)) !void {
        if (config.apiKey) |key| {
            try headers.put("X-BAPI-API-KEY", key);
        }
        
        const timestamp = try std.fmt.allocPrint(self.allocator, "{d}", .{time.now()});
        defer self.allocator.free(timestamp);
        try headers.put("X-BAPI-TIMESTAMP", timestamp);
        
        if (config.apiSecret) |secret| {
            var message = std.ArrayList(u8).init(self.allocator);
            defer message.deinit();
            
            try message.appendSlice(timestamp);
            try message.appendSlice(config.apiKey orelse "");
            
            const query_start = std.mem.indexOf(u8, url_all, "?");
            const params = if (query_start) |pos| url_all[pos..] else "";
            
            try message.appendSlice(params);
            try message.appendSlice(try switch (method) {
                "GET", "DELETE" => "",
                "POST", "PUT" => body orelse "",
                else => "",
            });
            
            const signature = try crypto.hmacSha256Hex(secret, message.items);
            
            try headers.put("X-BAPI-SIGN", &signature);
        }
    }
};

// Combined authentication manager
pub const AuthManager = struct {
    allocator: std.mem.Allocator,
    config: AuthConfig,
    nonce_generator: NonceGenerator,
    oauth_manager: ?OauthManager,
    
    pub fn init(allocator: std.mem.Allocator, config: AuthConfig) !AuthManager {
        return .{
            .allocator = allocator,
            .config = config,
            .nonce_generator = NonceGenerator.init(),
            .oauth_manager = null,
        };
    }
    
    pub fn deinit(self: *AuthManager) void {
        self.config.deinit(self.allocator);
        if (self.oauth_manager) |*oauth| {
            oauth.deinit();
        }
    }
    
    // Generate auth headers for a specific exchange
    pub fn generateHeaders(self: *AuthManager, exchange: []const u8, method: []const u8, url: []const u8, body: ?[]const u8) !std.StringHashMap([]const u8) {
        var headers = std.StringHashMap([]const u8).init(self.allocator);
        
        const exchange_auth = ExchangeAuth.init(self.allocator);
        
        if (std.mem.eql(u8, exchange, "binance")) {
            try exchange_auth.binanceAuth(self.config, method, url, body, &headers);
        } else if (std.mem.eql(u8, exchange, "kraken")) {
            try exchange_auth.krakenAuth(self.config, method, url, body, &headers);
        } else if (std.mem.eql(u8, exchange, "coinbase")) {
            try exchange_auth.coinbaseAuth(self.config, method, url, body, &headers);
        } else if (std.mem.eql(u8, exchange, "okx")) {
            try exchange_auth.okxAuth(self.config, method, url, body, &headers);
        } else if (std.mem.eql(u8, exchange, "bybit")) {
            try exchange_auth.bybitAuth(self.config, method, url, body, &headers);
        }
        
        return headers;
    }
    
    pub fn generateNonce(self: *AuthManager) u64 {
        return self.nonce_generator.generate();
    }
};