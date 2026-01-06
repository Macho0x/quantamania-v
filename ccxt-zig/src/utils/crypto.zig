const std = @import("std");

// HMAC-SHA256 implementation
pub fn hmacSha256(key: []const u8, message: []const u8) ![32]u8 {
    var hmac = std.crypto.auth.hmac.sha2.HmacSha256.init(key);
    hmac.update(message);
    return hmac.finalResult();
}

// SHA256 implementation
pub fn sha256(data: []const u8) ![32]u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    hasher.update(data);
    var output: [32]u8 = undefined;
    hasher.final(&output);
    return output;
}

// MD5 implementation (legacy support)
pub fn md5(data: []const u8) ![16]u8 {
    var hasher = std.crypto.hash.Md5.init();
    hasher.update(data);
    var output: [16]u8 = undefined;
    hasher.final(&output);
    return output;
}

// Base64 encoding
pub fn base64Encode(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    const encoded_len = std.base64.standard.Encoder.calcSize(data.len);
    var encoded = try allocator.alloc(u8, encoded_len);
    errdefer allocator.free(encoded);
    
    _ = std.base64.standard.Encoder.encode(encoded, data);
    return encoded;
}

// Base64 decoding
pub fn base64Decode(allocator: std.mem.Allocator, encoded: []const u8) ![]u8 {
    const decoded_len = std.base64.standard.Decoder.calcSizeForSlice(encoded) catch |err| {
        return err;
    };
    var decoded = try allocator.alloc(u8, decoded_len);
    errdefer allocator.free(decoded);
    
    std.base64.standard.Decoder.decode(decoded, encoded) catch |err| {
        return err;
    };
    
    return decoded;
}

// URL-safe Base64 encoding
pub fn base64UrlEncode(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    const encoded_len = std.base64.url_safe_no_pad.Encoder.calcSize(data.len);
    var encoded = try allocator.alloc(u8, encoded_len);
    errdefer allocator.free(encoded);
    
    _ = std.base64.url_safe_no_pad.Encoder.encode(encoded, data);
    return encoded;
}

// URL-safe Base64 decoding
pub fn base64UrlDecode(allocator: std.mem.Allocator, encoded: []const u8) ![]u8 {
    const decoded_len = std.base64.url_safe_no_pad.Decoder.calcSizeForSlice(encoded) catch |err| {
        return err;
    };
    var decoded = try allocator.alloc(u8, decoded_len);
    errdefer allocator.free(decoded);
    
    std.base64.url_safe_no_pad.Decoder.decode(decoded, encoded) catch |err| {
        return err;
    };
    
    return decoded;
}

// Hex encoding
pub fn hexEncode(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    const hex_len = data.len * 2;
    var hex = try allocator.alloc(u8, hex_len);
    errdefer allocator.free(hex);
    
    _ = std.fmt.bufPrint(hex, "{x}", .{std.fmt.fmtSliceHexLower(data)}) catch |err| {
        return err;
    };
    
    return hex;
}

// Hex decoding
pub fn hexDecode(allocator: std.mem.Allocator, hex: []const u8) ![]u8 {
    if (hex.len % 2 != 0) return error.InvalidHexLength;
    
    const data_len = hex.len / 2;
    var data = try allocator.alloc(u8, data_len);
    errdefer allocator.free(data);
    
    for (0..data_len) |i| {
        const hex_byte = hex[i * 2 .. i * 2 + 2];
        const byte = std.fmt.parseInt(u8, hex_byte, 16) catch |err| {
            return err;
        };
        data[i] = byte;
    }
    
    return data;
}

// Gzip decompression
pub fn decompressGzip(allocator: std.mem.Allocator, compressed: []const u8) ![]u8 {
    // Use zlib for gzip decompression
    var stream = std.compress.gzip.decompressStream(allocator, .{});
    defer stream.deinit();
    
    var output = std.ArrayList(u8).init(allocator);
    defer output.deinit();
    
    try stream.update(compressed);
    
    var buffer: [4096]u8 = undefined;
    while (true) {
        const bytes_read = stream.read(&buffer) catch |err| {
            return err;
        };
        if (bytes_read == 0) break;
        
        try output.appendSlice(buffer[0..bytes_read]);
    }
    
    return output.toOwnedSlice();
}

// Signing methods
pub const Signer = struct {
    pub fn hmacSha256Hex(key: []const u8, message: []const u8) ![64]u8 {
        const signature = try hmacSha256(key, message);
        var hex: [64]u8 = undefined;
        _ = std.fmt.bufPrint(&hex, "{x}", .{std.fmt.fmtSliceHexLower(&signature)}) catch unreachable;
        return hex;
    }
    
    pub fn hmacSha256Base64(allocator: std.mem.Allocator, key: []const u8, message: []const u8) ![]u8 {
        const signature = try hmacSha256(key, message);
        return try base64Encode(allocator, &signature);
    }
    
    pub fn sha256Hex(data: []const u8) ![64]u8 {
        const hash = try sha256(data);
        var hex: [64]u8 = undefined;
        _ = std.fmt.bufPrint(&hex, "{x}", .{std.fmt.fmtSliceHexLower(&hash)}) catch unreachable;
        return hex;
    }
    
    pub fn sha256Base64(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
        const hash = try sha256(data);
        return try base64Encode(allocator, &hash);
    }
};

// Nonce generation
pub fn generateNonce() u64 {
    const now = std.time.milliTimestamp();
    return @intCast(now);
}

pub fn generateNonceString(allocator: std.mem.Allocator) ![]u8 {
    const nonce = generateNonce();
    return std.fmt.allocPrint(allocator, "{d}", .{nonce});
}

// Utility functions
pub fn trim(allocator: std.mem.Allocator, str: []const u8) []u8 {
    var start: usize = 0;
    var end: usize = str.len;
    
    while (start < end and std.ascii.isSpace(str[start])) start += 1;
    while (end > start and std.ascii.isSpace(str[end - 1])) end -= 1;
    
    return allocator.dupe(u8, str[start..end]) catch @panic("trim: out of memory");
}