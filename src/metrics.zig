const std = @import("std");

/// Latency tracker with percentile calculation
pub const LatencyTracker = struct {
    const MAX_SAMPLES = 10000;

    samples: [MAX_SAMPLES]i128,
    count: std.atomic.Value(usize),
    total_count: std.atomic.Value(u64),

    pub fn init() LatencyTracker {
        return LatencyTracker{
            .samples = [_]i128{0} ** MAX_SAMPLES,
            .count = std.atomic.Value(usize).init(0),
            .total_count = std.atomic.Value(u64).init(0),
        };
    }

    pub fn record(self: *LatencyTracker, latency_ns: i128) void {
        _ = self.total_count.fetchAdd(1, .monotonic);

        const current_count = self.count.load(.acquire);
        if (current_count < MAX_SAMPLES) {
            self.samples[current_count] = latency_ns;
            _ = self.count.fetchAdd(1, .release);
        }
    }

    pub fn getPercentile(self: *LatencyTracker, percentile: f64) ?i128 {
        const current_count = self.count.load(.acquire);
        if (current_count == 0) return null;

        // Copy and sort samples
        var sorted: [MAX_SAMPLES]i128 = self.samples;
        std.mem.sort(i128, sorted[0..current_count], {}, comptime std.sort.asc(i128));

        const index = @as(usize, @intFromFloat(@as(f64, @floatFromInt(current_count)) * percentile));
        return sorted[@min(index, current_count - 1)];
    }

    pub fn getP50(self: *LatencyTracker) ?i128 {
        return self.getPercentile(0.50);
    }

    pub fn getP95(self: *LatencyTracker) ?i128 {
        return self.getPercentile(0.95);
    }

    pub fn getP99(self: *LatencyTracker) ?i128 {
        return self.getPercentile(0.99);
    }

    pub fn getMean(self: *LatencyTracker) ?i128 {
        const current_count = self.count.load(.acquire);
        if (current_count == 0) return null;

        var sum: i128 = 0;
        for (self.samples[0..current_count]) |sample| {
            sum += sample;
        }

        return @divFloor(sum, @as(i128, @intCast(current_count)));
    }

    pub fn reset(self: *LatencyTracker) void {
        self.count.store(0, .release);
    }

    pub fn getTotalCount(self: *LatencyTracker) u64 {
        return self.total_count.load(.monotonic);
    }
};

/// Throughput counter
pub const ThroughputCounter = struct {
    messages: std.atomic.Value(u64),
    orders: std.atomic.Value(u64),
    start_time: i128,

    pub fn init() ThroughputCounter {
        return ThroughputCounter{
            .messages = std.atomic.Value(u64).init(0),
            .orders = std.atomic.Value(u64).init(0),
            .start_time = std.time.nanoTimestamp(),
        };
    }

    pub fn recordMessage(self: *ThroughputCounter) void {
        _ = self.messages.fetchAdd(1, .monotonic);
    }

    pub fn recordOrder(self: *ThroughputCounter) void {
        _ = self.orders.fetchAdd(1, .monotonic);
    }

    pub fn getMessagesPerSecond(self: *ThroughputCounter) f64 {
        const elapsed_ns = std.time.nanoTimestamp() - self.start_time;
        const elapsed_s = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0;
        const msg_count = @as(f64, @floatFromInt(self.messages.load(.monotonic)));

        if (elapsed_s > 0) {
            return msg_count / elapsed_s;
        }
        return 0.0;
    }

    pub fn getOrdersPerSecond(self: *ThroughputCounter) f64 {
        const elapsed_ns = std.time.nanoTimestamp() - self.start_time;
        const elapsed_s = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0;
        const order_count = @as(f64, @floatFromInt(self.orders.load(.monotonic)));

        if (elapsed_s > 0) {
            return order_count / elapsed_s;
        }
        return 0.0;
    }

    pub fn getMessageCount(self: *ThroughputCounter) u64 {
        return self.messages.load(.monotonic);
    }

    pub fn getOrderCount(self: *ThroughputCounter) u64 {
        return self.orders.load(.monotonic);
    }

    pub fn reset(self: *ThroughputCounter) void {
        self.messages.store(0, .release);
        self.orders.store(0, .release);
        self.start_time = std.time.nanoTimestamp();
    }
};

/// Performance metrics aggregator
pub const PerformanceMetrics = struct {
    latency: LatencyTracker,
    throughput: ThroughputCounter,

    pub fn init() PerformanceMetrics {
        return PerformanceMetrics{
            .latency = LatencyTracker.init(),
            .throughput = ThroughputCounter.init(),
        };
    }

    pub fn recordOrderLatency(self: *PerformanceMetrics, latency_ns: i128) void {
        self.latency.record(latency_ns);
    }

    pub fn recordMessage(self: *PerformanceMetrics) void {
        self.throughput.recordMessage();
    }

    pub fn recordOrder(self: *PerformanceMetrics) void {
        self.throughput.recordOrder();
    }

    pub fn printSummary(self: *PerformanceMetrics, writer: anytype) !void {
        try writer.print("=== Performance Metrics ===\n", .{});
        try writer.print("Messages: {d}\n", .{self.throughput.getMessageCount()});
        try writer.print("Orders:   {d}\n", .{self.throughput.getOrderCount()});
        try writer.print("Messages/sec: {d:.0}\n", .{self.throughput.getMessagesPerSecond()});
        try writer.print("Orders/sec:   {d:.0}\n", .{self.throughput.getOrdersPerSecond()});

        if (self.latency.getP50()) |p50| {
            try writer.print("\nLatency (microseconds):\n", .{});
            try writer.print("  P50: {d}\n", .{@divFloor(p50, 1000)});

            if (self.latency.getP95()) |p95| {
                try writer.print("  P95: {d}\n", .{@divFloor(p95, 1000)});
            }

            if (self.latency.getP99()) |p99| {
                try writer.print("  P99: {d}\n", .{@divFloor(p99, 1000)});
            }

            if (self.latency.getMean()) |mean| {
                try writer.print("  Mean: {d}\n", .{@divFloor(mean, 1000)});
            }
        }
    }

    pub fn reset(self: *PerformanceMetrics) void {
        self.latency.reset();
        self.throughput.reset();
    }
};

test "LatencyTracker percentiles" {
    var tracker = LatencyTracker.init();

    // Record some samples
    var i: i64 = 1;
    while (i <= 100) : (i += 1) {
        tracker.record(i * 1000);
    }

    const p50 = tracker.getP50();
    const p95 = tracker.getP95();
    const p99 = tracker.getP99();

    try std.testing.expect(p50 != null);
    try std.testing.expect(p95 != null);
    try std.testing.expect(p99 != null);

    try std.testing.expect(p50.? < p95.?);
    try std.testing.expect(p95.? < p99.?);
}

test "ThroughputCounter" {
    var counter = ThroughputCounter.init();

    counter.recordMessage();
    counter.recordMessage();
    counter.recordOrder();

    try std.testing.expectEqual(@as(u64, 2), counter.getMessageCount());
    try std.testing.expectEqual(@as(u64, 1), counter.getOrderCount());
}

test "PerformanceMetrics integration" {
    var metrics = PerformanceMetrics.init();

    var i: usize = 0;
    while (i < 100) : (i += 1) {
        metrics.recordMessage();
        metrics.recordOrderLatency(@as(i64, @intCast(i)) * 1000);
    }

    try std.testing.expectEqual(@as(u64, 100), metrics.throughput.getMessageCount());
    try std.testing.expect(metrics.latency.getP50() != null);
}
