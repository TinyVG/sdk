const std = @import("std");
const tvg = @import("tvg");

const c = @cImport({
    @cInclude("tinyvg.h");
});

fn renderSvg(data: []const u8, stream: CWriter) !void {
    var temp_mem = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer temp_mem.deinit();

    try tvg.svg.renderBinary(temp_mem.allocator(), data, stream);
}

fn renderBitmap(data: []const u8, src_anti_alias: c.tinyvg_AntiAlias, width: u32, height: u32, bitmap: *c.tinyvg_Bitmap) !void {
    var temp_mem = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer temp_mem.deinit();

    const size_hint: tvg.rendering.SizeHint = if (width == 0 and height == 0)
        .inherit
    else if (width == 0)
        tvg.rendering.SizeHint{ .height = height }
    else if (height == 0)
        tvg.rendering.SizeHint{ .width = width }
    else
        tvg.rendering.SizeHint{ .size = .{ .width = width, .height = height } };
    const anti_alias: tvg.rendering.AntiAliasing = @enumFromInt(src_anti_alias);

    var image = try tvg.rendering.renderBuffer(
        temp_mem.allocator(),
        std.heap.page_allocator,
        size_hint,
        anti_alias,
        data,
    );
    errdefer image.deinit(std.heap.page_allocator);

    const pixel_data = std.mem.sliceAsBytes(image.pixels);

    std.debug.assert(pixel_data.len == 4 * @as(usize, image.width) * @as(usize, image.height));
    bitmap.* = .{
        .width = image.width,
        .height = image.height,
        .pixels = pixel_data.ptr,
    };
}

export fn tinyvg_render_svg(
    tvg_data_ptr: [*]const u8,
    tvg_length: usize,
    target: [*c]const c.tinyvg_OutStream,
) c.tinyvg_Error {
    renderSvg(
        tvg_data_ptr[0..tvg_length],
        CWriter{ .context = target },
    ) catch |err| return errToC(err);
    return c.TINYVG_SUCCESS;
}

export fn tinyvg_render_bitmap(
    tvg_data_ptr: [*]const u8,
    tvg_length: usize,
    anti_alias: c.tinyvg_AntiAlias,
    width: u32,
    height: u32,
    bitmap: [*c]c.tinyvg_Bitmap,
) c.tinyvg_Error {
    renderBitmap(
        tvg_data_ptr[0..tvg_length],
        if (anti_alias < 1) 1 else anti_alias,
        width,
        height,
        bitmap,
    ) catch |err| return errToC(err);
    return c.TINYVG_SUCCESS;
}

export fn tinyvg_free_bitmap(bitmap: *c.tinyvg_Bitmap) void {
    std.heap.page_allocator.free(bitmap.pixels[0 .. 4 * @as(usize, bitmap.width) * @as(usize, bitmap.height)]);
    bitmap.* = undefined;
}

const CError = error{
    OutOfMemory,
    IoError,
    EndOfStream,
    InvalidData,
    UnsupportedColorFormat,
    UnsupportedVersion,
    Unsupported,
};

fn errToZig(err: c.tinyvg_Error) CError!void {
    switch (err) {
        c.TINYVG_SUCCESS => {},
        c.TINYVG_ERR_OUT_OF_MEMORY => return error.OutOfMemory,
        c.TINYVG_ERR_IO => return error.IoError,
        c.TINYVG_ERR_INVALID_DATA => return error.InvalidData,
        c.TINYVG_ERR_UNSUPPORTED => return error.Unsupported,
        else => @panic("invalid error code!"),
    }
}

fn errToC(err: CError) c.tinyvg_Error {
    return switch (err) {
        error.OutOfMemory => c.TINYVG_ERR_OUT_OF_MEMORY,
        error.IoError => c.TINYVG_ERR_IO,
        error.EndOfStream => c.TINYVG_ERR_IO,
        error.InvalidData => c.TINYVG_ERR_INVALID_DATA,
        error.UnsupportedColorFormat => c.TINYVG_ERR_UNSUPPORTED,
        error.UnsupportedVersion => c.TINYVG_ERR_UNSUPPORTED,
        error.Unsupported => c.TINYVG_ERR_UNSUPPORTED,
    };
}

const CWriter = std.io.Writer(*const c.tinyvg_OutStream, CError, writeCStream);

fn writeCStream(stream: *const c.tinyvg_OutStream, data: []const u8) CError!usize {
    var written: usize = 0;

    try errToZig(stream.write.?(stream.context, data.ptr, data.len, &written));

    return written;
}
