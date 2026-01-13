const std = @import("std");

// URL encoding/decoding
pub const UrlUtils = struct {
    pub fn encode(allocator: std.mem.Allocator, raw: []const u8) ![]u8 {
        const hex = "0123456789ABCDEF";
        // Allocate worst-case length
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();
        
        for (raw) |byte| {
            const is_unreserved = switch (byte) {
                // Unreserved characters per RFC 3986
                'A'...'Z', 'a'...'z', '0'...'9', '-', '_', '.', '~' => true,
                else => false,
            };
            
            if (is_unreserved) {
                try buffer.append(byte);
            } else {
                try buffer.append('%');
                try buffer.append(hex[byte >> 4]);
                try buffer.append(hex[byte & 0x0F]);
            }
        }
        
        return buffer.toOwnedSlice();
    }
    
    pub fn decode(allocator: std.mem.Allocator, encoded: []const u8) ![]u8 {
        // Allocate buffer for worst-case (all unencoded)
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();
        
        var i: usize = 0;
        while (i < encoded.len) : (i += 1) {
            if (encoded[i] == '%' and i + 2 < encoded.len) {
                const hex1 = encoded[i + 1];
                const hex2 = encoded[i + 2];
                
                const byte = try parseHexByte(hex1, hex2);
                try buffer.append(byte);
                i += 2; // Skip the next two characters
            } else if (encoded[i] == '+') {
                try buffer.append(' ');
            } else {
                try buffer.append(encoded[i]);
            }
        }
        
        return buffer.toOwnedSlice();
    }
};

fn parseHexByte(hex1: u8, hex2: u8) !u8 {
    const charToHex = struct {
        fn func(ch: u8) !u4 {
            return switch (ch) {
                '0'...'9' => @intCast(ch - '0'),
                'A'...'F' => @intCast(ch - 'A' + 10),
                'a'...'f' => @intCast(ch - 'a' + 10),
                else => error.InvalidHexCharacter,
            };
        }
    }.func;
    
    const high = try charToHex(hex1);
    const low = try charToHex(hex2);
    return @as(u8, high << 4) | low;
}

// Query parameter building
pub const QueryBuilder = struct {
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator) QueryBuilder {
        return .{ .allocator = allocator };
    }
    
    pub fn buildFromMap(self: *QueryBuilder, map: anytype) ![]u8 {
        var buffer = std.ArrayList(u8).init(self.allocator);
        defer buffer.deinit();
        
        var iterator = map.iterator();
        var first = true;
        
        while (iterator.next()) |entry| {
            if (!first) {
                try buffer.append('&');
            } else {
                first = false;
            }
            
            const key = try UrlUtils.encode(self.allocator, entry.key_ptr.*);
            defer self.allocator.free(key);
            try buffer.appendSlice(key);
            try buffer.append('=');
            
            const value = try UrlUtils.encode(self.allocator, entry.value_ptr.*);
            defer self.allocator.free(value);
            try buffer.appendSlice(value);
        }
        
        return buffer.toOwnedSlice();
    }
};

// URL parsing and building
pub const ParsedUrl = struct {
    scheme: []const u8,
    host: []const u8,
    port: ?u16,
    path: []const u8,
    query: ?[]const u8,
    fragment: ?[]const u8,
    
    pub fn format(self: ParsedUrl, allocator: std.mem.Allocator) ![]u8 {
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();
        
        try buffer.appendSlice(self.scheme);
        try buffer.appendSlice("://");
        try buffer.appendSlice(self.host);
        
        if (self.port) |port| {
            try std.fmt.format(buffer.writer(), ":{d}", .{port});
        }
        
        try buffer.appendSlice(self.path);
        
        if (self.query) |query| {
            try buffer.append('?');
            try buffer.appendSlice(query);
        }
        
        if (self.fragment) |fragment| {
            try buffer.append('#');
            try buffer.appendSlice(fragment);
        }
        
        return buffer.toOwnedSlice();
    }
};

pub const Url = struct {
    // Parse URL into components
    pub fn parse(url: []const u8) !ParsedUrl {
        var result = ParsedUrl{
            .scheme = "",
            .host = "",
            .port = null,
            .path = "/",
            .query = null,
            .fragment = null,
        };
        
        // Parse scheme
        var rest = url;
        if (std.mem.indexOf(u8, url, "://")) |pos| {
            result.scheme = url[0..pos];
            rest = url[pos + 3..];
        } else {
            return error.MissingScheme;
        }
        
        // Parse host and port
        const path_start = std.mem.indexOfAny(u8, rest, "/?#");
        const host_port = if (path_start) |pos| rest[0..pos] else rest;
        
        if (std.mem.indexOfScalar(u8, host_port, ':')) |colon_pos| {
            result.host = host_port[0..colon_pos];
            result.port = try std.fmt.parseInt(u16, host_port[colon_pos + 1..], 10);
        } else {
            result.host = host_port;
            
            // Set default ports
            if (std.mem.eql(u8, result.scheme, "https")) {
                result.port = 443;
            } else if (std.mem.eql(u8, result.scheme, "http")) {
                result.port = 80;
            }
        }
        
        if (path_start == null) return result;
        
        // Parse path, query, fragment
        var remaining = rest[path_start.?..];
        
        while (remaining.len > 0) {
            switch (remaining[0]) {
                '/' => {
                    const query_pos = std.mem.indexOfAny(u8, remaining[1..], "?#");
                    if (query_pos) |pos| {
                        result.path = remaining[0..pos + 1];
                        remaining = remaining[pos + 1..];
                    } else {
                        result.path = remaining;
                        break;
                    }
                },
                '?' => {
                    const fragment_pos = std.mem.indexOfScalar(u8, remaining[1..], '#');
                    if (fragment_pos) |pos| {
                        result.query = remaining[1..pos + 1];
                        remaining = remaining[pos + 1..];
                    } else {
                        result.query = remaining[1..];
                        break;
                    }
                },
                '#' => {
                    result.fragment = remaining[1..];
                    break;
                },
                else => break,
            }
        }
        
        if (result.path.len == 0) {
            result.path = "/";
        }
        
        return result;
    }
    
    // Build URL from components
    pub fn build(allocator: std.mem.Allocator, components: ParsedUrl) ![]u8 {
        return components.format(allocator);
    }
    
    // Join path segments correctly
    pub fn joinPath(allocator: std.mem.Allocator, paths: [][]const u8) ![]u8 {
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();
        
        for (paths, 0..) |path, i| {
            const is_last = i == paths.len - 1;
            
            if (path.len == 0) continue;
            
            // Remove leading slash if not first path
            const start_pos: usize = if (i > 0 and path[0] == '/') 1 else 0;
            
            // Remove trailing slash if not last path
            const end_pos: usize = if (!is_last and path[path.len - 1] == '/')
                path.len - 1
            else
                path.len;
            
            if (i > 0 and buffer.items.len > 0 and buffer.items[buffer.items.len - 1] != '/') {
                try buffer.append('/');
            }
            
            try buffer.appendSlice(path[start_pos..end_pos]);
        }
        
        return buffer.toOwnedSlice();
    }
    
    // Check if URL is absolute
    pub fn isAbsolute(url: []const u8) bool {
        return std.mem.indexOf(u8, url, "://") != null;
    }
    
    // Get base URL (scheme + host + port)
    pub fn getBaseUrl(allocator: std.mem.Allocator, url: []const u8) ![]u8 {
        const parsed = try parse(url);
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();
        
        try buffer.appendSlice(parsed.scheme);
        try buffer.appendSlice("://");
        try buffer.appendSlice(parsed.host);
        
        if (parsed.port) |port| {
            if ((std.mem.eql(u8, parsed.scheme, "https") and port != 443) or
                (std.mem.eql(u8, parsed.scheme, "http") and port != 80)) {
                try std.fmt.format(buffer.writer(), ":{d}", .{port});
            }
        }
        
        return buffer.toOwnedSlice();
    }
