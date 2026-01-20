const std = @import("std");
const base = @import("../base/errors.zig");
const types = @import("./types.zig");

// WebSocket RFC 6455 OpCodes
pub const WebSocketOpcode = enum(u4) {
    continuation = 0x0,
    text = 0x1,
    binary = 0x2,
    close = 0x8,
    ping = 0x9,
    pong = 0xA,
};

// Connection states
pub const ConnectionState = enum {
    disconnected,
    connecting,
    connected,
    reconnecting,
    error,
};

// WebSocket errors
pub const WebSocketError = error{
    NotConnected,
    ConnectionRefused,
    HandshakeFailed,
    FrameParseError,
    ProtocolError,
    TimeoutError,
    TLSError,
    InvalidPayload,
    MaxReconnectAttempts,
    NetworkError,
    SSLHandshakeError,
    DNSError,
    BufferOverflow,
};

// WebSocket frame structure
pub const WebSocketFrame = struct {
    fin: bool,
    opcode: WebSocketOpcode,
    masked: bool,
    payload_length: u64,
    mask_key: [4]u8,
    payload: []u8,

    pub fn encode(self: *const WebSocketFrame, allocator: std.mem.Allocator) ![]u8 {
        var buffer = std.ArrayList(u8).init(allocator);

        // First byte: FIN + RSV + OPCODE
        var first_byte: u8 = 0;
        if (self.fin) first_byte |= 0x80;
        first_byte |= @intFromEnum(self.opcode);
        try buffer.append(first_byte);

        // Second byte: MASK + LENGTH
        var second_byte: u8 = 0;
        if (self.masked) second_byte |= 0x80;

        if (self.payload_length < 126) {
            second_byte |= @as(u8, @intCast(self.payload_length));
            try buffer.append(second_byte);
        } else if (self.payload_length < 65536) {
            second_byte |= 126;
            try buffer.append(second_byte);
            // Big-endian 16-bit length
            var len16 = @as(u16, @intCast(self.payload_length));
            var bytes: [2]u8 = undefined;
            bytes[0] = @byteCast(len16 >> 8);
            bytes[1] = @byteCast(len16 & 0xFF);
            try buffer.appendSlice(&bytes);
        } else {
            second_byte |= 127;
            try buffer.append(second_byte);
            // Big-endian 64-bit length
            var len64 = self.payload_length;
            var bytes: [8]u8 = undefined;
            bytes[0] = @byteCast(@as(u8, @intCast(len64 >> 56)));
            bytes[1] = @byteCast(@as(u8, @intCast(len64 >> 48)));
            bytes[2] = @byteCast(@as(u8, @intCast(len64 >> 40)));
            bytes[3] = @byteCast(@as(u8, @intCast(len64 >> 32)));
            bytes[4] = @byteCast(@as(u8, @intCast(len64 >> 24)));
            bytes[5] = @byteCast(@as(u8, @intCast(len64 >> 16)));
            bytes[6] = @byteCast(@as(u8, @intCast(len64 >> 8)));
            bytes[7] = @byteCast(@as(u8, @intCast(len64)));
            try buffer.appendSlice(&bytes);
        }

        // Mask key (if masked)
        if (self.masked) {
            try buffer.appendSlice(&self.mask_key);
        }

        // Payload (with masking if needed)
        if (self.masked) {
            const masked_payload = try allocator.alloc(u8, self.payload.len);
            defer allocator.free(masked_payload);
            for (self.payload, 0..) |byte, i| {
                masked_payload[i] = byte ^ self.mask_key[i % 4];
            }
            try buffer.appendSlice(masked_payload);
        } else {
            try buffer.appendSlice(self.payload);
        }

        return buffer.toOwnedSlice();
    }

    pub fn decode(data: []const u8, allocator: std.mem.Allocator) !WebSocketFrame {
        if (data.len < 2) return WebSocketError.FrameParseError;

        var offset: usize = 0;

        // Parse first byte
        const first_byte = data[offset];
        offset += 1;
        const fin = (first_byte & 0x80) != 0;
        const opcode_val = first_byte & 0x0F;
        const opcode = @as(WebSocketOpcode, @enumFromInt(opcode_val));

        // Parse second byte
        const second_byte = data[offset];
        offset += 1;
        const masked = (second_byte & 0x80) != 0;
        var payload_length = @as(u64, second_byte & 0x7F);

        // Extended payload length
        if (payload_length == 126) {
            if (data.len < offset + 2) return WebSocketError.FrameParseError;
            payload_length = (@as(u64, data[offset]) << 8) | @as(u64, data[offset + 1]);
            offset += 2;
        } else if (payload_length == 127) {
            if (data.len < offset + 8) return WebSocketError.FrameParseError;
            payload_length = 0;
            for (0..8) |i| {
                payload_length = (payload_length << 8) | @as(u64, data[offset + i]);
            }
            offset += 8;
        }

        // Mask key
        var mask_key: [4]u8 = undefined;
        if (masked) {
            if (data.len < offset + 4) return WebSocketError.FrameParseError;
            @memcpy(&mask_key, data[offset..offset + 4]);
            offset += 4;
        }

        // Payload
        if (data.len < offset + payload_length) return WebSocketError.FrameParseError;
        const payload = try allocator.alloc(u8, payload_length);
        @memcpy(payload, data[offset..offset + payload_length]);

        // Unmask if needed
        if (masked) {
            for (payload, 0..) |*byte, i| {
                byte.* ^= mask_key[i % 4];
            }
        }

        return WebSocketFrame{
            .fin = fin,
            .opcode = opcode,
            .masked = masked,
            .payload_length = payload_length,
            .mask_key = mask_key,
            .payload = payload,
        };
    }
};

// URL parser for WebSocket connections
const URL = struct {
    scheme: []const u8,
    host: []const u8,
    port: u16,
    path: []const u8,
    is_secure: bool,

    pub fn parse(url_str: []const u8, allocator: std.mem.Allocator) !URL {
        var it = std.mem.split(u8, url_str, "://");
        const scheme = it.next() orelse return WebSocketError.InvalidPayload;

        const rest = it.rest();
        var host_it = std.mem.split(u8, rest, "/");
        const host_port = host_it.next() orelse return WebSocketError.InvalidPayload;
        const path = host_it.rest();

        // Parse host and port
        var host: []const u8 = host_port;
        var port: u16 = if (std.mem.eql(u8, scheme, "wss")) 443 else 80;

        if (std.mem.indexOf(u8, host_port, ":")) |colon_idx| {
            host = host_port[0..colon_idx];
            const port_str = host_port[colon_idx + 1..];
            port = std.fmt.parseInt(u16, port_str, 10) catch return WebSocketError.InvalidPayload;
        }

        return URL{
            .scheme = try allocator.dupe(u8, scheme),
            .host = try allocator.dupe(u8, host),
            .port = port,
            .path = try allocator.dupe(u8, if (path.len == 0) "/" else path),
            .is_secure = std.mem.eql(u8, scheme, "wss"),
        };
    }

    pub fn deinit(self: *URL, allocator: std.mem.Allocator) void {
        allocator.free(self.scheme);
        allocator.free(self.host);
        allocator.free(self.path);
    }
};

// WebSocket message types
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

// Reconnection configuration
const ReconnectConfig = struct {
    max_attempts: u32 = 5,
    base_delay_ms: u64 = 1000,
    max_delay_ms: u64 = 30000,
    backoff_multiplier: f64 = 2.0,
};

// WebSocket client
pub const WebSocketClient = struct {
    allocator: std.mem.Allocator,
    url: []const u8,
    parsed_url: URL,
    state: ConnectionState,
    stream: ?std.net.Stream,
    read_buffer: std.ArrayList(u8),
    message_queue: std.ArrayList(WebSocketMessage),
    reconnect_config: ReconnectConfig,
    reconnect_attempts: u32,
    last_ping_time: i64,
    connection_timeout_ms: u64 = 30000,
    ping_interval_ms: u64 = 30000,
    mutex: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator, url: []const u8) !WebSocketClient {
        const parsed_url = try URL.parse(url, allocator);

        return WebSocketClient{
            .allocator = allocator,
            .url = try allocator.dupe(u8, url),
            .parsed_url = parsed_url,
            .state = .disconnected,
            .stream = null,
            .read_buffer = std.ArrayList(u8).init(allocator),
            .message_queue = std.ArrayList(WebSocketMessage).init(allocator),
            .reconnect_config = .{},
            .reconnect_attempts = 0,
            .last_ping_time = 0,
            .mutex = std.Thread.Mutex{},
        };
    }

    pub fn deinit(self: *WebSocketClient) void {
        self.disconnect() catch {};
        self.parsed_url.deinit(self.allocator);
        self.allocator.free(self.url);

        // Clean up message queue
        for (self.message_queue.items) |*msg| {
            msg.deinit(self.allocator);
        }
        self.message_queue.deinit();
        self.read_buffer.deinit();
    }

    // Generate a random 32-bit mask key
    fn generateMaskKey() [4]u8 {
        var key: [4]u8 = undefined;
        std.crypto.random.bytes(&key);
        return key;
    }

    // Perform WebSocket handshake
    fn performHandshake(self: *WebSocketClient) !void {
        const key_bytes = generateMaskKey();
        const key_b64 = std.base64.standard.Encoder.encode(&key_bytes);

        // Build handshake request
        const request = try std.fmt.allocPrint(
            self.allocator,
            "GET {s} HTTP/1.1\r\n" ++
                "Host: {s}\r\n" ++
                "Upgrade: websocket\r\n" ++
                "Connection: Upgrade\r\n" ++
                "Sec-WebSocket-Key: {s}\r\n" ++
                "Sec-WebSocket-Version: 13\r\n" ++
                "\r\n",
            .{
                self.parsed_url.path,
                self.parsed_url.host,
                key_b64,
            }
        );
        defer self.allocator.free(request);

        // Send handshake request
        const stream = self.stream.?;
        try stream.writeAll(request);

        // Read response
        var response_buffer: [4096]u8 = undefined;
        const bytes_read = try stream.read(&response_buffer);
        const response = response_buffer[0..bytes_read];

        // Parse response headers
        var it = std.mem.split(u8, response, "\r\n");
        const status_line = it.next() orelse return WebSocketError.HandshakeFailed;

        if (!std.mem.eql(u8, status_line, "HTTP/1.1 101 Switching Protocols")) {
            return WebSocketError.HandshakeFailed;
        }

        // Check for required headers
        var has_upgrade = false;
        var has_connection = false;
        var has_accept = false;
        var accept_key: []const u8 = "";

        while (it.next()) |line| {
            if (line.len == 0) continue;

            var header_it = std.mem.split(u8, line, ":");
            const header_name = header_it.next() orelse continue;
            const header_value = header_it.rest();

            if (std.ascii.eqlIgnoreCase(header_name, "Upgrade")) {
                has_upgrade = std.mem.eql(u8, std.mem.trim(u8, header_value, " "), "websocket");
            } else if (std.ascii.eqlIgnoreCase(header_name, "Connection")) {
                has_connection = std.mem.eql(u8, std.mem.trim(u8, header_value, " "), "Upgrade");
            } else if (std.ascii.eqlIgnoreCase(header_name, "Sec-WebSocket-Accept")) {
                has_accept = true;
                accept_key = std.mem.trim(u8, header_value, " ");
            }
        }

        if (!has_upgrade or !has_connection or !has_accept) {
            return WebSocketError.HandshakeFailed;
        }

        // Validate Sec-WebSocket-Accept
        var sha1_hash: [20]u8 = undefined;
        const input = try std.fmt.allocPrint(self.allocator, "{s}258EAFA5-E914-47DA-95CA-C5AB0DC85B11", .{key_b64});
        defer self.allocator.free(input);
        std.crypto.hash.sha1(input, &sha1_hash, .{});
        const expected_accept = std.base64.standard.Encoder.encode(&sha1_hash);

        if (!std.mem.eql(u8, accept_key, expected_accept)) {
            return WebSocketError.HandshakeFailed;
        }
    }

    // Establish TCP connection with timeout
    fn establishConnection(self: *WebSocketClient) !void {
        // Create TCP connection
        self.stream = try std.net.tcpConnectToHost(self.allocator, self.parsed_url.host, self.parsed_url.port);
        const stream = self.stream.?;

        // Set socket timeouts
        const timeout = std.time.ns_per_ms * self.connection_timeout_ms;
        try stream.setReadTimeout(timeout);
        try stream.setWriteTimeout(timeout);

        // TLS handshake if needed (simplified - TODO: implement proper TLS)
        if (self.parsed_url.is_secure) {
            // For now, we'll skip TLS as it's complex and not always needed for testing
            _ = stream;
        }
    }

    pub fn connect(self: *WebSocketClient) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.state == .connected) return;

        self.state = .connecting;

        // Establish TCP connection
        try self.establishConnection();

        // Perform WebSocket handshake
        try self.performHandshake();

        self.state = .connected;
        self.reconnect_attempts = 0;
        self.last_ping_time = std.time.milliTimestamp();
    }

    pub fn disconnect(self: *WebSocketClient) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.state != .disconnected) {
            // Send close frame
            if (self.state == .connected) {
                self.sendCloseFrame(1000, "") catch {};
            }
            
            if (self.stream) |*stream| {
                stream.close();
            }
            
            self.state = .disconnected;
            
            // Clear message queue
            for (self.message_queue.items) |*msg| {
                msg.deinit(self.allocator);
            }
            self.message_queue.clearRetainingCapacity();
            self.read_buffer.clearRetainingCapacity();
        }
    }

    pub fn isConnected(self: *WebSocketClient) bool {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.state == .connected;
    }

    pub fn getState(self: *WebSocketClient) ConnectionState {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.state;
    }

    // Send text frame
    pub fn sendText(self: *WebSocketClient, payload: []const u8) WebSocketError!void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.state != .connected) {
            return WebSocketError.NotConnected;
        }

        try self.sendFrame(.text, payload);
    }

    // Send binary frame
    pub fn sendBinary(self: *WebSocketClient, payload: []const u8) WebSocketError!void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.state != .connected) {
            return WebSocketError.NotConnected;
        }

        try self.sendFrame(.binary, payload);
    }

    // Internal method to send frames
    fn sendFrame(self: *WebSocketClient, opcode: WebSocketOpcode, payload: []const u8) !void {
        const mask_key = generateMaskKey();
        const frame = WebSocketFrame{
            .fin = true,
            .opcode = opcode,
            .masked = true,
            .payload_length = payload.len,
            .mask_key = mask_key,
            .payload = @constCast(payload),
        };

        const encoded_frame = try frame.encode(self.allocator);
        defer self.allocator.free(encoded_frame);

        const stream = self.stream.?;
        try stream.writeAll(encoded_frame);
    }

    // Send close frame
    fn sendCloseFrame(self: *WebSocketClient, code: u16, reason: []const u8) !void {
        var payload = std.ArrayList(u8).init(self.allocator);
        defer payload.deinit();

        // Close code (2 bytes, big endian)
        const code_bytes = [_]u8{ @byteCast(code >> 8), @byteCast(code & 0xFF) };
        try payload.appendSlice(&code_bytes);

        // Close reason
        if (reason.len > 0) {
            try payload.appendSlice(reason);
        }

        const mask_key = generateMaskKey();
        const frame = WebSocketFrame{
            .fin = true,
            .opcode = .close,
            .masked = true,
            .payload_length = payload.items.len,
            .mask_key = mask_key,
            .payload = payload.items,
        };

        const encoded_frame = try frame.encode(self.allocator);
        defer self.allocator.free(encoded_frame);

        const stream = self.stream.?;
        try stream.writeAll(encoded_frame);
    }

    // Receive and process messages
    pub fn recv(self: *WebSocketClient, allocator: std.mem.Allocator) WebSocketError!WebSocketMessage {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.state != .connected) {
            return WebSocketError.NotConnected;
        }

        // Check for pending messages in queue
        if (self.message_queue.items.len > 0) {
            const msg = self.message_queue.orderedRemove(0);
            return msg;
        }

        // Read and parse frames
        try self.processIncomingFrames(allocator);

        // Check again for messages
        if (self.message_queue.items.len > 0) {
            const msg = self.message_queue.orderedRemove(0);
            return msg;
        }

        // Send ping if needed
        const now = std.time.milliTimestamp();
        if (now - self.last_ping_time > self.ping_interval_ms) {
            try self.sendPingFrame();
            self.last_ping_time = now;
        }

        // No messages available
        return WebSocketError.NotConnected;
    }

    // Process incoming frames
    fn processIncomingFrames(self: *WebSocketClient, allocator: std.mem.Allocator) !void {
        const stream = self.stream.?;

        // Read from socket
        var buffer: [4096]u8 = undefined;
        const bytes_read = stream.read(&buffer) catch |err| {
            switch (err) {
                error.WouldBlock, error.ResourceBusy, error.Interrupted => return,
                else => {
                    // Connection lost, attempt reconnection
                    self.handleConnectionLost();
                    return;
                },
            }
        };

        if (bytes_read == 0) {
            // Connection closed
            self.handleConnectionLost();
            return;
        }

        try self.read_buffer.appendSlice(buffer[0..bytes_read]);

        // Parse frames
        while (self.read_buffer.items.len >= 2) {
            const first_byte = self.read_buffer.items[0];
            const second_byte = self.read_buffer.items[1];
            const masked = (second_byte & 0x80) != 0;
            
            var payload_length = @as(u64, second_byte & 0x7F);
            var header_size: usize = 2;
            
            if (payload_length == 126) {
                if (self.read_buffer.items.len < 4) break;
                payload_length = (@as(u64, self.read_buffer.items[2]) << 8) | @as(u64, self.read_buffer.items[3]);
                header_size = 4;
            } else if (payload_length == 127) {
                if (self.read_buffer.items.len < 10) break;
                payload_length = 0;
                for (2..10) |i| {
                    payload_length = (payload_length << 8) | @as(u64, self.read_buffer.items[i]);
                }
                header_size = 10;
            }

            if (masked) header_size += 4;

            const frame_size = header_size + payload_length;
            if (self.read_buffer.items.len < frame_size) break;

            // Extract and parse frame
            const frame_data = try allocator.alloc(u8, frame_size);
            @memcpy(frame_data, self.read_buffer.items[0..frame_size]);
            const frame = try WebSocketFrame.decode(frame_data, allocator);
            defer allocator.free(frame_data);

            // Handle frame based on opcode
            try self.handleFrame(&frame, allocator);

            // Remove processed frame from buffer
            self.read_buffer.replaceRange(0, frame_size, &[]) catch unreachable;
        }
    }

    // Handle individual frames
    fn handleFrame(self: *WebSocketClient, frame: *const WebSocketFrame, allocator: std.mem.Allocator) !void {
        switch (frame.opcode) {
            .text => {
                const msg = try allocator.alloc(u8, frame.payload.len);
                @memcpy(msg, frame.payload);
                try self.message_queue.append(.{ .typ = .text, .data = msg });
            },
            .binary => {
                const msg = try allocator.alloc(u8, frame.payload.len);
                @memcpy(msg, frame.payload);
                try self.message_queue.append(.{ .typ = .binary, .data = msg });
            },
            .ping => {
                // Respond with pong
                try self.sendPongFrame();
            },
            .pong => {
                // Update last ping time
                self.last_ping_time = std.time.milliTimestamp();
            },
            .close => {
                // Connection closing, update state
                self.state = .disconnected;
                if (self.stream) |*stream| {
                    stream.close();
                }
            },
            .continuation => {
                // Handle fragmented messages (simplified)
                // In a full implementation, you'd need to track fragmented message state
            },
        }
    }

    // Send pong frame
    fn sendPongFrame(self: *WebSocketClient) !void {
        const mask_key = generateMaskKey();
        const frame = WebSocketFrame{
            .fin = true,
            .opcode = .pong,
            .masked = true,
            .payload_length = 0,
            .mask_key = mask_key,
            .payload = &[_]u8{},
        };

        const encoded_frame = try frame.encode(self.allocator);
        defer self.allocator.free(encoded_frame);

        const stream = self.stream.?;
        try stream.writeAll(encoded_frame);
    }

    // Send ping frame
    fn sendPingFrame(self: *WebSocketClient) !void {
        const mask_key = generateMaskKey();
        const frame = WebSocketFrame{
            .fin = true,
            .opcode = .ping,
            .masked = true,
            .payload_length = 0,
            .mask_key = mask_key,
            .payload = &[_]u8{},
        };

        const encoded_frame = try frame.encode(self.allocator);
        defer self.allocator.free(encoded_frame);

        const stream = self.stream.?;
        try stream.writeAll(encoded_frame);
    }

    // Handle connection loss and attempt reconnection
    fn handleConnectionLost(self: *WebSocketClient) void {
        if (self.reconnect_attempts >= self.reconnect_config.max_attempts) {
            self.state = .error;
            return;
        }

        self.state = .reconnecting;
        self.reconnect_attempts += 1;

        // Calculate delay with exponential backoff
        const delay = @as(u64, @intFromFloat(
            @as(f64, @floatFromInt(self.reconnect_config.base_delay_ms)) *
            std.math.pow(f64, self.reconnect_config.backoff_multiplier, @as(f64, @floatFromInt(self.reconnect_attempts - 1)))
        ));
        const capped_delay = @min(delay, self.reconnect_config.max_delay_ms);

        // Attempt reconnection after delay
        std.time.sleep(capped_delay * std.time.ns_per_ms);

        self.connect() catch {
            self.handleConnectionLost();
        };
    }
};

// Export error types for external use
pub const Error = WebSocketError;

// Message type exports
pub const Message = WebSocketMessage;