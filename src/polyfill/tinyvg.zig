const std = @import("std");
const builtin = @import("builtin");
const tvg = @import("tvg");

extern "tinyvg" fn setResultSvg(svg_ptr: [*]const u8, svg_len: usize) void;
extern "tinyvg" fn getSourceTvg(tvg_ptr: [*]u8, tvg_len: usize) void;

extern "platform" fn platformPanic(ptr: [*]const u8, len: usize) void;
extern "platform" fn platformLogWrite(ptr: [*]const u8, len: usize) void;
extern "platform" fn platformLogFlush() void;

fn convertToSvgSafe(tvg_len: usize) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const src_buffer = try allocator.alloc(u8, tvg_len);
    defer allocator.free(src_buffer);

    getSourceTvg(src_buffer.ptr, tvg_len);

    var destination = std.ArrayList(u8).init(allocator);
    defer destination.deinit();

    try tvg.svg.renderBinary(allocator, src_buffer[0..tvg_len], destination.writer());

    setResultSvg(destination.items.ptr, destination.items.len);
}

export fn convertToSvg(tvg_len: usize) u32 {
    convertToSvgSafe(tvg_len) catch |err| {
        return switch (err) {
            error.OutOfMemory => 1,
            error.EndOfStream => 2,
            error.InvalidData => 3,
            error.UnsupportedVersion => 4,
            error.UnsupportedColorFormat => 5,
        };
    };
    return 0;
}

const WriteError = error{};
const LogWriter = std.io.Writer(void, WriteError, writeLog);

fn writeLog(_: void, msg: []const u8) WriteError!usize {
    platformLogWrite(msg.ptr, msg.len);
    return msg.len;
}

/// Overwrite default log handler
pub fn log(
    comptime message_level: std.log.Level,
    comptime scope: @Type(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    if (builtin.mode != .ReleaseSmall) {
        const level_txt = switch (message_level) {
            .err => "error",
            .warn => "warning",
            .info => "info",
            .debug => "debug",
        };
        const prefix2 = if (scope == .default) ": " else "(" ++ @tagName(scope) ++ "): ";

        (LogWriter{ .context = {} }).print(level_txt ++ prefix2 ++ format ++ "\n", args) catch return;

        platformLogFlush();
    }
}

/// Overwrite default panic handler
pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace) noreturn {
    // std.log.crit("panic: {s}", .{msg});
    platformPanic(msg.ptr, msg.len);
    unreachable;
}
