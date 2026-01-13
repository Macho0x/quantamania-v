const std = @import("std");

pub const WebSocketError = error{
    NotConnected,
    NotImplemented,
};

pub const MessageType = enum {
    text,
    binary,
};

pub const WebSocketMessage = struct {
    typ: MessageType,
    data: []const u8,

    pub fn deinit(self: *WebSocketMessage, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
    }
};

pub const WebSocketClient = struct {
    allocator: std.mem.Allocator,
    url: []const u8,
    connected: bool = false,

    pub fn init(allocator: std.mem.Allocator, url: []const u8) !WebSocketClient {
        return .{
            .allocator = allocator,
            .url = try allocator.dupe(u8, url),
            .connected = false,
        };
    }

    pub fn deinit(self: *WebSocketClient) void {
        self.allocator.free(self.url);
    }

    pub fn connect(self: *WebSocketClient) !void {
        self.connected = true;
    }

    pub fn close(self: *WebSocketClient) void {
        self.connected = false;
    }

    pub fn sendText(self: *WebSocketClient, payload: []const u8) WebSocketError!void {
        _ = payload;
        if (!self.connected) return WebSocketError.NotConnected;
        return WebSocketError.NotImplemented;
    }

    pub fn sendBinary(self: *WebSocketClient, payload: []const u8) WebSocketError!void {
        _ = payload;
        if (!self.connected) return WebSocketError.NotConnected;
        return WebSocketError.NotImplemented;
    }

    pub fn recv(self: *WebSocketClient, allocator: std.mem.Allocator) WebSocketError!WebSocketMessage {
        _ = allocator;
        if (!self.connected) return WebSocketError.NotConnected;
        return WebSocketError.NotImplemented;
    }
};
