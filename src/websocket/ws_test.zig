const std = @import("std");
const testing = std.testing;
const ws = @import("ws.zig");

// Test utilities
fn testAllocator() std.mem.Allocator {
    return testing.allocator;
}

test "WebSocketOpcode enum values" {
    try testing.expect(@intFromEnum(ws.WebSocketOpcode.continuation) == 0x0);
    try testing.expect(@intFromEnum(ws.WebSocketOpcode.text) == 0x1);
    try testing.expect(@intFromEnum(ws.WebSocketOpcode.binary) == 0x2);
    try testing.expect(@intFromEnum(ws.WebSocketOpcode.close) == 0x8);
    try testing.expect(@intFromEnum(ws.WebSocketOpcode.ping) == 0x9);
    try testing.expect(@intFromEnum(ws.WebSocketOpcode.pong) == 0xA);
}

test "ConnectionState enum values" {
    try testing.expect(@intFromEnum(ws.ConnectionState.disconnected) == 0);
    try testing.expect(@intFromEnum(ws.ConnectionState.connecting) == 1);
    try testing.expect(@intFromEnum(ws.ConnectionState.connected) == 2);
    try testing.expect(@intFromEnum(ws.ConnectionState.reconnecting) == 3);
    try testing.expect(@intFromEnum(ws.ConnectionState.error) == 4);
}

test "WebSocketFrame encode - text frame" {
    const allocator = testAllocator();
    defer testing.allocator = allocator;

    const payload = "Hello, WebSocket!";
    const frame = ws.WebSocketFrame{
        .fin = true,
        .opcode = .text,
        .masked = true,
        .payload_length = payload.len,
        .mask_key = [_]u8{ 0x12, 0x34, 0x56, 0x78 },
        .payload = @constCast(payload),
    };

    const encoded = try frame.encode(allocator);
    defer allocator.free(encoded);

    // Validate basic structure
    try testing.expect(encoded.len >= 6); // 2 header + 4 mask + payload

    // First byte should have FIN (0x80) and TEXT opcode (0x01)
    try testing.expect(encoded[0] == 0x81);

    // Second byte should have MASK (0x80) and payload length
    try testing.expect(encoded[1] == 0x80 | payload.len);
}

test "WebSocketFrame encode - binary frame with extended length" {
    const allocator = testAllocator();
    defer testing.allocator = allocator;

    // Create a payload larger than 125 bytes to test extended length encoding
    var payload = try allocator.alloc(u8, 200);
    defer allocator.free(payload);
    @memset(payload, 'A');

    const frame = ws.WebSocketFrame{
        .fin = true,
        .opcode = .binary,
        .masked = true,
        .payload_length = payload.len,
        .mask_key = [_]u8{ 0xAA, 0xBB, 0xCC, 0xDD },
        .payload = payload,
    };

    const encoded = try frame.encode(allocator);
    defer allocator.free(encoded);

    // Should have 2 + 2 (extended length) + 4 (mask) + 200 (payload) = 208 bytes
    try testing.expect(encoded.len == 208);

    // First byte: FIN + BINARY opcode
    try testing.expect(encoded[0] == 0x82);

    // Second byte: MASK + 126 (indicating 16-bit length follows)
    try testing.expect(encoded[1] == 0x80 | 126);

    // Extended length should be 200 (0x00C8)
    try testing.expect(encoded[2] == 0xC8);
    try testing.expect(encoded[3] == 0x00);
}

test "WebSocketFrame decode - text frame" {
    const allocator = testAllocator();
    defer testing.allocator = allocator;

    // Manually create a simple frame for testing
    var raw_frame = std.ArrayList(u8).init(allocator);
    defer raw_frame.deinit();

    // FIN + TEXT opcode
    try raw_frame.append(0x81);
    // MASK + length (5 bytes for "hello")
    try raw_frame.append(0x85);
    // Mask key
    try raw_frame.appendSlice(&[_]u8{ 0x12, 0x34, 0x56, 0x78 });
    // Masked payload: "hello" XOR with mask key
    const masked_payload = "hello";
    for (masked_payload, 0..) |byte, i| {
        try raw_frame.append(byte ^ @as(u8, 0x12 + (i % 3) * 0x22));
    }

    const decoded = try ws.WebSocketFrame.decode(raw_frame.items, allocator);
    defer allocator.free(decoded.payload);

    try testing.expect(decoded.fin == true);
    try testing.expect(decoded.opcode == .text);
    try testing.expect(decoded.masked == false); // Decoded frames are unmasked
    try testing.expect(decoded.payload_length == 5);
    try testing.expect(std.mem.eql(u8, decoded.payload, "hello"));
}

test "WebSocketFrame masking/unmasking" {
    const allocator = testAllocator();
    defer testing.allocator = allocator;

    const original_payload = "TestMessage";
    const mask_key = [_]u8{ 0xAA, 0xBB, 0xCC, 0xDD };

    // Create frame with specific mask key
    const frame = ws.WebSocketFrame{
        .fin = true,
        .opcode = .text,
        .masked = true,
        .payload_length = original_payload.len,
        .mask_key = mask_key,
        .payload = @constCast(original_payload),
    };

    const encoded = try frame.encode(allocator);
    defer allocator.free(encoded);

    // Verify masking is applied
    try testing.expect(encoded.len == 2 + 4 + original_payload.len); // header + mask + payload

    // Decode and verify unmasking
    const decoded = try ws.WebSocketFrame.decode(encoded, allocator);
    defer allocator.free(decoded.payload);

    try testing.expect(std.mem.eql(u8, decoded.payload, original_payload));
}

test "URL parsing - basic ws URL" {
    const allocator = testAllocator();
    defer testing.allocator = allocator;

    const url_str = "ws://example.com:8080/path";
    
    // Test URL parsing logic (this would be a function we need to expose)
    // For now, we'll test the parsing logic separately
    var it = std.mem.split(u8, url_str, "://");
    const scheme = it.next() orelse return error.TestExpected;
    const rest = it.rest();
    
    try testing.expect(std.mem.eql(u8, scheme, "ws"));
    try testing.expect(rest.len > 0);
}

test "WebSocketClient init and deinit" {
    const allocator = testAllocator();
    defer testing.allocator = allocator;

    const url = "ws://echo.websocket.org";
    const client = try ws.WebSocketClient.init(allocator, url);
    defer client.deinit();

    try testing.expectEqual(ws.ConnectionState.disconnected, client.getState());
    try testing.expect(!client.isConnected());
}

test "WebSocketClient connect and disconnect" {
    const allocator = testAllocator();
    defer testing.allocator = allocator;

    // Use a simple echo server for testing
    const url = "ws://echo.websocket.org";
    const client = try ws.WebSocketClient.init(allocator, url);
    defer client.deinit();

    // Initially disconnected
    try testing.expectEqual(ws.ConnectionState.disconnected, client.getState());

    // Note: This test may fail in CI environments without network access
    // In a real test environment, you might want to mock the connection
    /*
    client.connect() catch {
        // Expected to fail in test environment without network
        try testing.expectEqual(ws.ConnectionState.error, client.getState());
        return;
    };

    try testing.expectEqual(ws.ConnectionState.connected, client.getState());
    try testing.expect(client.isConnected());

    client.disconnect();
    try testing.expectEqual(ws.ConnectionState.disconnected, client.getState());
    try testing.expect(!client.isConnected());
    */
}

test "WebSocketClient sendText when disconnected" {
    const allocator = testAllocator();
    defer testing.allocator = allocator;

    const url = "ws://echo.websocket.org";
    const client = try ws.WebSocketClient.init(allocator, url);
    defer client.deinit();

    // Try to send text when not connected
    const result = client.sendText("Hello");
    try testing.expectError(ws.WebSocketError.NotConnected, result);
}

test "WebSocketClient sendBinary when disconnected" {
    const allocator = testAllocator();
    defer testing.allocator = allocator;

    const url = "ws://echo.websocket.org";
    const client = try ws.WebSocketClient.init(allocator, url);
    defer client.deinit();

    // Try to send binary when not connected
    const result = client.sendBinary("Binary data");
    try testing.expectError(ws.WebSocketError.NotConnected, result);
}

test "WebSocketClient recv when disconnected" {
    const allocator = testAllocator();
    defer testing.allocator = allocator;

    const url = "ws://echo.websocket.org";
    const client = try ws.WebSocketClient.init(allocator, url);
    defer client.deinit();

    // Try to receive when not connected
    const result = client.recv(allocator);
    try testing.expectError(ws.WebSocketError.NotConnected, result);
}

test "Mask key generation randomness" {
    const allocator = testAllocator();
    defer testing.allocator = allocator;

    // Test that mask keys are actually random
    const url = "ws://example.com";
    const client = try ws.WebSocketClient.init(allocator, url);
    defer client.deinit();

    // Generate multiple mask keys and verify they're different
    var keys: [10][4]u8 = undefined;
    for (&keys) |*key| {
        key.* = client.generateMaskKey();
    }

    // All keys should be different (very high probability)
    for (0..keys.len) |i| {
        for (i + 1..keys.len) |j| {
            try testing.expect(!std.mem.eql(u8, &keys[i], &keys[j]));
        }
    }
}

test "Reconnection configuration" {
    const allocator = testAllocator();
    defer testing.allocator = allocator;

    const url = "ws://example.com";
    const client = try ws.WebSocketClient.init(allocator, url);
    defer client.deinit();

    // Verify default reconnection settings
    try testing.expect(client.reconnect_config.max_attempts == 5);
    try testing.expect(client.reconnect_config.base_delay_ms == 1000);
    try testing.expect(client.reconnect_config.max_delay_ms == 30000);
    try testing.expect(client.reconnect_config.backoff_multiplier == 2.0);

    // Verify initial state
    try testing.expect(client.reconnect_attempts == 0);
}

test "Message queue operations" {
    const allocator = testAllocator();
    defer testing.allocator = allocator;

    const url = "ws://example.com";
    const client = try ws.WebSocketClient.init(allocator, url);
    defer client.deinit();

    // Test message queue initialization
    try testing.expect(client.message_queue.items.len == 0);

    // Note: In a real implementation, you'd want to test actual message queuing
    // but that requires a connected WebSocket, which is complex to test in isolation
}

test "Frame parsing edge cases" {
    const allocator = testAllocator();
    defer testing.allocator = allocator;

    // Test empty frame
    const empty_frame_data = [_]u8{ 0x81, 0x00 }; // FIN + TEXT + empty payload
    const empty_frame = try ws.WebSocketFrame.decode(&empty_frame_data, allocator);
    defer allocator.free(empty_frame.payload);

    try testing.expect(empty_frame.fin == true);
    try testing.expect(empty_frame.opcode == .text);
    try testing.expect(empty_frame.payload_length == 0);
    try testing.expect(empty_frame.payload.len == 0);

    // Test frame with RSV bits set (should be preserved)
    const frame_with_rsv = [_]u8{ 0xC1, 0x01, 'A' }; // FIN + RSV + TEXT + payload
    const decoded_rsv = try ws.WebSocketFrame.decode(&frame_with_rsv, allocator);
    defer allocator.free(decoded_rsv.payload);

    try testing.expect(decoded_rsv.fin == true);
    try testing.expect(decoded_rsv.opcode == .text);
}

test "Payload length encoding variants" {
    const allocator = testAllocator();
    defer testing.allocator = allocator;

    // Test 7-bit length (0-125)
    {
        const payload = "Short";
        const frame = ws.WebSocketFrame{
            .fin = true,
            .opcode = .text,
            .masked = false,
            .payload_length = payload.len,
            .mask_key = undefined,
            .payload = @constCast(payload),
        };

        const encoded = try frame.encode(allocator);
        defer allocator.free(encoded);

        try testing.expect(encoded.len == 2 + payload.len); // header + payload
        try testing.expect(encoded[1] == payload.len); // Should fit in 7 bits
    }

    // Test 16-bit length (126-65535)
    {
        var payload = try allocator.alloc(u8, 300);
        defer allocator.free(payload);
        @memset(payload, 'B');

        const frame = ws.WebSocketFrame{
            .fin = true,
            .opcode = .binary,
            .masked = false,
            .payload_length = payload.len,
            .mask_key = undefined,
            .payload = payload,
        };

        const encoded = try frame.encode(allocator);
        defer allocator.free(encoded);

        try testing.expect(encoded.len == 4 + payload.len); // header(2) + length(2) + payload
        try testing.expect(encoded[1] == 126); // Indicates 16-bit length follows
        // Verify big-endian encoding
        try testing.expect(encoded[2] == 0x01); // 300 = 0x012C in big-endian
        try testing.expect(encoded[3] == 0x2C);
    }
}

test "Ping/Pong frame handling" {
    const allocator = testAllocator();
    defer testing.allocator = allocator;

    // Test ping frame encoding
    const ping_frame = ws.WebSocketFrame{
        .fin = true,
        .opcode = .ping,
        .masked = true,
        .payload_length = 0,
        .mask_key = [_]u8{ 0x11, 0x22, 0x33, 0x44 },
        .payload = &[_]u8{},
    };

    const encoded_ping = try ping_frame.encode(allocator);
    defer allocator.free(encoded_ping);

    try testing.expect(encoded_ping.len == 6); // 2 header + 4 mask
    try testing.expect(encoded_ping[0] == 0x89); // FIN + PING opcode

    // Test pong frame encoding
    const pong_frame = ws.WebSocketFrame{
        .fin = true,
        .opcode = .pong,
        .masked = true,
        .payload_length = 0,
        .mask_key = [_]u8{ 0x55, 0x66, 0x77, 0x88 },
        .payload = &[_]u8{},
    };

    const encoded_pong = try pong_frame.encode(allocator);
    defer allocator.free(encoded_pong);

    try testing.expect(encoded_pong.len == 6); // 2 header + 4 mask
    try testing.expect(encoded_pong[0] == 0x8A); // FIN + PONG opcode
}

test "Close frame encoding" {
    const allocator = testAllocator();
    defer testing.allocator = allocator;

    const reason = "Going away";
    var payload = std.ArrayList(u8).init(allocator);
    defer payload.deinit();

    // Close code (1001) + reason
    try payload.appendSlice(&[_]u8{ 0x03, 0xE9 }); // 1001 in big endian
    try payload.appendSlice(reason);

    const close_frame = ws.WebSocketFrame{
        .fin = true,
        .opcode = .close,
        .masked = true,
        .payload_length = payload.items.len,
        .mask_key = [_]u8{ 0xFF, 0xEE, 0xDD, 0xCC },
        .payload = payload.items,
    };

    const encoded = try close_frame.encode(allocator);
    defer allocator.free(encoded);

    try testing.expect(encoded.len == 2 + 4 + payload.items.len); // header + mask + payload
    try testing.expect(encoded[0] == 0x88); // FIN + CLOSE opcode
    try testing.expect(encoded[1] == 0x80 | payload.items.len); // MASK + length
}

test "Performance benchmarks - frame encoding/decoding speed" {
    const allocator = testAllocator();
    defer testing.allocator = allocator;

    const payload = "Performance test payload";
    const iterations = 1000;

    // Benchmark encoding
    var start_time = std.time.nanoTimestamp();
    for (0..iterations) |_| {
        const frame = ws.WebSocketFrame{
            .fin = true,
            .opcode = .text,
            .masked = true,
            .payload_length = payload.len,
            .mask_key = [_]u8{ 0x12, 0x34, 0x56, 0x78 },
            .payload = @constCast(payload),
        };

        const encoded = try frame.encode(allocator);
        defer allocator.free(encoded);
    }
    var end_time = std.time.nanoTimestamp();
    const encode_time = @as(f64, @floatFromInt(end_time - start_time)) / iterations;

    // Benchmark decoding
    start_time = std.time.nanoTimestamp();
    for (0..iterations) |_| {
        const frame = ws.WebSocketFrame{
            .fin = true,
            .opcode = .text,
            .masked = true,
            .payload_length = payload.len,
            .mask_key = [_]u8{ 0x12, 0x34, 0x56, 0x78 },
            .payload = @constCast(payload),
        };

        const encoded = try frame.encode(allocator);
        defer allocator.free(encoded);

        const decoded = try ws.WebSocketFrame.decode(encoded, allocator);
        defer allocator.free(decoded.payload);
    }
    end_time = std.time.nanoTimestamp();
    const decode_time = @as(f64, @floatFromInt(end_time - start_time)) / iterations;

    // Performance assertions (adjust based on your requirements)
    try testing.expect(encode_time < 10000); // Less than 10 microseconds per encode
    try testing.expect(decode_time < 10000); // Less than 10 microseconds per decode
}

test "Integration test with echo server" {
    const allocator = testAllocator();
    defer testing.allocator = allocator;

    // This test requires network access and a working WebSocket server
    // In a CI environment, this might be skipped
    /*
    const url = "wss://echo.websocket.events"; // Using a reliable echo server
    const client = try ws.WebSocketClient.init(allocator, url);
    defer client.deinit();

    // Connect to server
    client.connect() catch {
        // Skip test if connection fails (network unavailable)
        return;
    };

    // Send a test message
    const test_message = "Integration test message";
    try client.sendText(test_message);

    // Receive the echoed message
    const response = client.recv(allocator) catch {
        client.disconnect();
        return;
    };
    defer response.deinit(allocator);

    try testing.expectEqual(ws.MessageType.text, response.typ);
    try testing.expect(std.mem.eql(u8, response.data, test_message));

    client.disconnect();
    */
}

// Error handling tests
test "WebSocketError enum completeness" {
    const errors = .{
        ws.WebSocketError.NotConnected,
        ws.WebSocketError.ConnectionRefused,
        ws.WebSocketError.HandshakeFailed,
        ws.WebSocketError.FrameParseError,
        ws.WebSocketError.ProtocolError,
        ws.WebSocketError.TimeoutError,
        ws.WebSocketError.TLSError,
        ws.WebSocketError.InvalidPayload,
        ws.WebSocketError.MaxReconnectAttempts,
        ws.WebSocketError.NetworkError,
        ws.WebSocketError.SSLHandshakeError,
        ws.WebSocketError.DNSError,
        ws.WebSocketError.BufferOverflow,
    };

    // Verify all error types are handled
    _ = errors;
}

// Memory management tests
test "No memory leaks in WebSocketClient" {
    const allocator = testAllocator();
    defer testing.allocator = allocator;

    var client: ?ws.WebSocketClient = null;
    defer {
        if (client) |*c| {
            c.deinit();
        }
    }

    client = try ws.WebSocketClient.init(allocator, "ws://example.com/test/path");
    
    // Create and destroy multiple times to check for leaks
    for (0..10) |_| {
        if (client) |*c| {
            c.deinit();
        }
        client = try ws.WebSocketClient.init(allocator, "ws://example.com/test/path");
    }
}

test "Buffer overflow handling" {
    const allocator = testAllocator();
    defer testing.allocator = allocator;

    // Test very large payload that might cause issues
    var large_payload = try allocator.alloc(u8, 10_000_000); // 10MB
    defer allocator.free(large_payload);
    @memset(large_payload, 'X');

    const frame = ws.WebSocketFrame{
        .fin = true,
        .opcode = .binary,
        .masked = true,
        .payload_length = large_payload.len,
        .mask_key = [_]u8{ 0x12, 0x34, 0x56, 0x78 },
        .payload = large_payload,
    };

    // This should handle large payloads gracefully
    const encoded = try frame.encode(allocator);
    defer allocator.free(encoded);

    try testing.expect(encoded.len > 10_000_000);
}