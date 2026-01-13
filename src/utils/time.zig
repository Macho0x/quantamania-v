const std = @import("std");

// Timestamp utilities for handling timestamps in milliseconds
pub const TimeUtils = struct {
    // Unix epoch (seconds) to milliseconds conversion
    pub fn secondsToMs(seconds: i64) i64 {
        return seconds * 1000;
    }
    
    // Milliseconds to seconds conversion
    pub fn msToSeconds(ms: i64) i64 {
        return @divTrunc(ms, 1000);
    }
    
    // Milliseconds to ISO 8601 string
    pub fn msToISO8601(allocator: std.mem.Allocator, ms: i64) ![]u8 {
        const seconds = msToSeconds(ms);
        const timestamp = std.time.epoch.EpochSeconds{ .secs = @intCast(seconds) };
        const day = timestamp.getEpochDay();
        const day_seconds = timestamp.getDaySeconds();
        
        var date_time_buffer: [100]u8 = undefined;
        _ = std.time.epoch.YearMonthDay.fromEpochDay(day).formatRFC3339(&date_time_buffer, day_seconds);
        
        return allocator.dupe(u8, &date_time_buffer);
    }
    
    // ISO 8601 string to milliseconds
    pub fn ISO8601ToMs(allocator: std.mem.Allocator, iso8601_str: []const u8) !i64 {
        // Use simple parsing - in production, use a proper RFC3339 parser
        var timestamp: i64 = 0;
        
        // Parse basic format: YYYY-MM-DDTHH:MM:SS[.sss]Z
        if (iso8601_str.len < 20) return error.InvalidISO8601Format;
        
        const year = try std.fmt.parseInt(i32, iso8601_str[0..4], 10);
        const month = try std.fmt.parseInt(u8, iso8601_str[5..7], 10);
        const day = try std.fmt.parseInt(u8, iso8601_str[8..10], 10);
        
        const hour = try std.fmt.parseInt(u8, iso8601_str[11..13], 10);
        const minute = try std.fmt.parseInt(u8, iso8601_str[14..16], 10);
        const second = try std.fmt.parseInt(u8, iso8601_str[17..19], 10);
        
        // Create epoch time (simplified calculation)
        const days_since_epoch = try calculateDaysSinceEpoch(year, month, day);
        timestamp = secondsToMs(days_since_epoch * 86400 + hour * 3600 + minute * 60 + second);
        
        return timestamp;
    }
    
    // Current time in milliseconds
    pub fn now() i64 {
        return std.time.milliTimestamp();
    }
    
    // Sleep for specified milliseconds
    pub fn sleepMs(ms: u64) void {
        std.time.sleep(ms * std.time.ns_per_ms);
    }
};

// Days since Unix epoch (1970-01-01) for a given date
fn calculateDaysSinceEpoch(year: i32, month: u8, day: u8) !i64 {
    // Simplified calculation - in production use a proper date library
    const DAYS_IN_MONTH = [_]u8{ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
    
    var days: i64 = 0;
    
    // Years
    var y: i32 = 1970;
    while (y < year) : (y += 1) {
        days += if (isLeapYear(y)) 366 else 365;
    }
    
    // Months in current year
    var m: u8 = 1;
    while (m < month) : (m += 1) {
        var days_in_month: u8 = DAYS_IN_MONTH[m - 1];
        if (m == 2 and isLeapYear(year)) {
            days_in_month = 29;
        }
        days += days_in_month;
    }
    
    // Days in current month
    days += day - 1;
    
    return days;
}

fn isLeapYear(year: i32) bool {
    return (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0);
}

// TimeFrame utilities
pub const TimeFrame = enum {
    _1m, _5m, _15m, _30m,
    _1h, _2h, _4h, _6h, _8h, _12h,
    _1d, _3d,
    _1w, _2w,
    _1M,
    
    pub fn toMinutes(self: TimeFrame) i64 {
        return switch (self) {
            ._1m => 1,
            ._5m => 5,
            ._15m => 15,
            ._30m => 30,
            ._1h => 60,
            ._2h => 120,
            ._4h => 240,
            ._6h => 360,
            ._8h => 480,
            ._12h => 720,
            ._1d => 1440,
            ._3d => 4320,
            ._1w => 10080,
            ._2w => 20160,
            ._1M => 43200,
        };
    }
    
    pub fn toString(self: TimeFrame) []const u8 {
        return switch (self) {
            ._1m => "1m",
            ._5m => "5m",
            ._15m => "15m",
            ._30m => "30m",
            ._1h => "1h",
            ._2h => "2h",
            ._4h => "4h",
            ._6h => "6h",
            ._8h => "8h",
            ._12h => "12h",
            ._1d => "1d",
            ._3d => "3d",
            ._1w => "1w",
            ._2w => "2w",
            ._1M => "1M",
        };
    }
    
    pub fn parse(str: []const u8) !TimeFrame {
        return std.meta.stringToEnum(TimeFrame, str) orelse 
            error.InvalidTimeFrame;
    }
};

// Duration handling
pub const Duration = struct {
    milliseconds: i64,
    
    pub fn fromMinutes(minutes: i64) Duration {
        return .{ .milliseconds = minutes * 60 * 1000 };
    }
    
    pub fn fromHours(hours: i64) Duration {
        return .{ .milliseconds = hours * 60 * 60 * 1000 };
    }
    
    pub fn fromDays(days: i64) Duration {
        return .{ .milliseconds = days * 24 * 60 * 60 * 1000 };
    }
    
    pub fn minutes(self: Duration) i64 {
        return @divTrunc(self.milliseconds, 60 * 1000);
    }
    
    pub fn hours(self: Duration) i64 {
        return @divTrunc(self.milliseconds, 60 * 60 * 1000);
    }
    
    pub fn days(self: Duration) i64 {
        return @divTrunc(self.milliseconds, 24 * 60 * 60 * 1000);
    }
};

// Timezone support (UTC operations only in CCXT)
pub const Timezone = struct {
    // All times in CCXT are UTC
    pub const UTC_OFFSET: i32 = 0;
    
    // Convert timestamp to UTC timezone
    pub fn toUtc(timestamp_ms: i64) i64 {
        return timestamp_ms;
    }
    
    // Get current UTC timestamp
    pub fn utcNow() i64 {
        return now();
    }
    
    // Format timestamp as UTC ISO8601 string
    pub fn formatUtc(allocator: std.mem.Allocator, timestamp_ms: i64) ![]u8 {
        return try TimeUtils.msToISO8601(allocator, timestamp_ms);
    }
};

// Calculate next candle time based on timeframe
pub fn getNextCandleTime(current_ms: i64, timeframe: TimeFrame) i64 {
    const timeframe_ms = timeframe.toMinutes() * 60 * 1000;
    const remainder = @mod(current_ms, timeframe_ms);
    return current_ms + timeframe_ms - remainder;
}

// Check if timestamp is aligned to timeframe
pub fn isAlignedToTimeframe(timestamp_ms: i64, timeframe: TimeFrame) bool {
    const timeframe_ms = timeframe.toMinutes() * 60 * 1000;
    return @mod(timestamp_ms, timeframe_ms) == 0;
}

// Parse duration string (e.g., "1d", "2h", "30m")
pub fn parseDuration(duration_str: []const u8) !i64 {
    var multiplier: i64 = 1;
    var number_str = duration_str;
    
    if (duration_str.len > 0) {
        const last_char = duration_str[duration_str.len - 1];
        switch (last_char) {
            's' => { multiplier = 1000; number_str = duration_str[0..duration_str.len-1]; },
            'm' => { multiplier = 60 * 1000; number_str = duration_str[0..duration_str.len-1]; },
            'h' => { multiplier = 60 * 60 * 1000; number_str = duration_str[0..duration_str.len-1]; },
            'd' => { multiplier = 24 * 60 * 60 * 1000; number_str = duration_str[0..duration_str.len-1]; },
            'w' => { multiplier = 7 * 24 * 60 * 60 * 1000; number_str = duration_str[0..duration_str.len-1]; },
            'y' => { multiplier = 365 * 24 * 60 * 60 * 1000; number_str = duration_str[0..duration_str.len-1]; },
            else => {},
        }
    }
    
    const number = try std.fmt.parseInt(i64, number_str, 10);
    return number * multiplier;
}