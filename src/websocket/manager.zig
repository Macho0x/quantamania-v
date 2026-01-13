// WebSocket Connection Manager
// Phase 3.2 - WebSocket Support

const std = @import("std");
const ws = @import("ws.zig");

pub const WebSocketManager = struct {
    allocator: std.mem.Allocator,
    connections: std.StringHashMap(WebSocketConnection),
    
    pub fn init(allocator: std.mem.Allocator) !WebSocketManager {
        return .{
            .allocator = allocator,
            .connections = std.StringHashMap(WebSocketConnection).init(allocator),
        };
    }
    
    pub fn deinit(self: *WebSocketManager) void {
        var iter = self.connections.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.*deinit();
            self.allocator.free(entry.key_ptr.*);
        }
        self.connections.deinit();
    }
    
    pub fn addConnection(self: *WebSocketManager, id: []const u8, connection: WebSocketConnection) !void {
        const id_copy = try self.allocator.dupe(u8, id);
        try self.connections.put(id_copy, connection);
    }
    
    pub fn removeConnection(self: *WebSocketManager, id: []const u8) void {
        self.connections.remove(id);
    }
    
    pub fn getConnection(self: *WebSocketManager, id: []const u8) ?*WebSocketConnection {
        return self.connections.get(id);
    }
    
    pub fn getConnectionCount(self: *WebSocketManager) usize {
        return self.connections.count();
    }
};

pub const WebSocketConnection = struct {
    client: ws.WebSocketClient,
    url: []const u8,
    connected: bool,
    reconnect_attempts: u32,
    last_message_time: i64,
    
    pub fn init(allocator: std.mem.Allocator, url: []const u8) !WebSocketConnection {
        return .{
            .client = try ws.WebSocketClient.init(allocator, url),
            .url = try allocator.dupe(u8, url),
            .connected = false,
            .reconnect_attempts = 0,
            .last_message_time = 0,
        };
    }
    
    pub fn deinit(self: *WebSocketConnection) void {
        self.client.deinit();
        self.client.allocator.free(self.url);
    }
    
    pub fn connect(self: *WebSocketConnection) !void {
        try self.client.connect();
        self.connected = true;
        self.reconnect_attempts = 0;
        self.last_message_time = std.time.timestamp();
    }
    
    pub fn disconnect(self: *WebSocketConnection) void {
        self.client.close();
        self.connected = false;
    }
    
    pub fn isConnected(self: *WebSocketConnection) bool {
        return self.connected;
    }
    
    pub fn sendText(self: *WebSocketConnection, message: []const u8) !void {
        try self.client.sendText(message);
        self.last_message_time = std.time.timestamp();
    }
    
    pub fn sendBinary(self: *WebSocketConnection, data: []const u8) !void {
        try self.client.sendBinary(data);
        self.last_message_time = std.time.timestamp();
    }
    
    pub fn receive(self: *WebSocketConnection) !ws.WebSocketMessage {
        return try self.client.recv(self.client.allocator);
    }
    
    pub fn handleReconnect(self: *WebSocketConnection) !void {
        if (self.reconnect_attempts >= 5) {
            return error.MaxReconnectAttempts;
        }
        
        // Exponential backoff: 1s, 2s, 4s, 8s, 16s
        const delay = @as(u64, 1000 * (1 << self.reconnect_attempts));
        std.time.sleep(delay * 1_000_000); // Convert to nanoseconds
        
        self.reconnect_attempts += 1;
        try self.connect();
    }
};

pub const WebSocketError = ws.WebSocketError || error{
    MaxReconnectAttempts,
    ConnectionNotFound,
    AlreadyConnected,
    NotConnected,
};