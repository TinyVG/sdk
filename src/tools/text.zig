const std = @import("std");
const tvg = @import("tvg");
const args = @import("args");

fn printUsage(stream: anytype) !void {
    try stream.writeAll(
        \\tvg-text [-I <fmt>] [-O <fmt>] [-o <output>] <input>
        \\
        \\Converts TinyVG related files between different formats. Only supports a single input and output file.
        \\
        \\Options:
        \\  <input>                     defines the input file, performs auto detection of the format if -I is not specified. Use - for stdin.
        \\  -h, --help                  prints this text.
        \\  -I, --input-format  <fmt>   sets the format of the input file.
        \\  -O, --output-format <fmt>   sets the format of the output file.
        \\  -o, --output <file>         sets the output file, or use - for stdout. performs auto detection of the format if -O is not specified.
        \\
        \\Support formats:
        \\  tvg  - Tiny vector graphics, binary representation.
        \\  tvgt - Tiny vector graphics, text representation.
        \\  svg  - Scalable vector graphics. Only usable for output, use svg2tvgt to convert to tvg text format.
        \\
    );
}

const CliOptions = struct {
    help: bool = false,

    @"input-format": ?Format = null,
    @"output-format": ?Format = null,

    output: ?[]const u8 = null,

    pub const shorthands = .{
        .o = "output",
        .h = "help",
        .I = "input-format",
        .O = "output-format",
    };
};

const Format = enum {
    tvg,
    tvgt,
    svg,
};

fn detectFormat(ext: []const u8) ?Format {
    return if (std.mem.eql(u8, ext, ".tvg"))
        Format.tvg
    else if (std.mem.eql(u8, ext, ".tvgt"))
        Format.tvgt
    else if (std.mem.eql(u8, ext, ".svg"))
        Format.svg
    else
        null;
}

pub fn main() !u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const cli = args.parseForCurrentProcess(CliOptions, allocator, .print) catch return 1;
    defer cli.deinit();

    // const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    if (cli.options.help) {
        try printUsage(stdout);
        return 0;
    }

    if (cli.positionals.len != 1) {
        try stderr.writeAll("Expected exactly one positional argument!\n");
        try printUsage(stderr);
        return 1;
    }

    const input_file = cli.positionals[0];
    const input_ext = std.fs.path.extension(input_file);
    const input_format = cli.options.@"input-format" orelse
        detectFormat(input_ext) orelse {
        try stderr.print("Could not auto-detect the input format for extension {s}\n", .{input_ext});
        return 1;
    };

    const output_file = cli.options.output orelse blk: {
        if (cli.options.@"output-format" == null) {
            try stderr.print("Could not auto-detect the input format for extension {s}\n", .{input_ext});
            return 1;
        }
        const dest_ext: []const u8 = switch (cli.options.@"output-format".?) {
            .svg => ".svg",
            .tvg => ".tvg",
            .tvgt => ".tvgt",
        };
        break :blk try std.mem.join(allocator, "", &[_][]const u8{
            input_file[0 .. input_file.len - input_ext.len],
            dest_ext,
        });
    };
    const output_ext = std.fs.path.extension(output_file);
    const output_format = cli.options.@"output-format" orelse
        detectFormat(output_ext) orelse {
        try stderr.print("Could not auto-detect the output format for extension {s}\n", .{output_ext});
        return 1;
    };

    var intermediary_tvg = std.ArrayList(u8).init(allocator);
    defer intermediary_tvg.deinit();

    {
        var input_stream = try FileOrStream.openRead(std.fs.cwd(), input_file);
        defer input_stream.close();

        switch (input_format) {
            .tvg => {
                const buffer = try input_stream.file.readToEndAlloc(allocator, 1 << 24);

                intermediary_tvg.deinit();
                intermediary_tvg = std.ArrayList(u8).fromOwnedSlice(allocator, buffer);
            },

            .tvgt => {
                const text = try input_stream.reader().readAllAlloc(allocator, 1 << 25);
                defer allocator.free(text);

                try tvg.text.parse(allocator, text, intermediary_tvg.writer());
            },

            .svg => {
                try stderr.print("This tool cannot convert from SVG files. Use svg2tvg to convert the SVG to TVG textual representation.\n", .{});
                return 1;
            },
        }
    }

    // Conversion process:
    //
    // Read the input file and directly convert it to TVG (binary).
    // After that, write the output file via the TVG decoder.

    // std.log.err("input:  {s} {s}", .{ input_file, @tagName(input_format) });
    // std.log.err("output: {s} {s}", .{ output_file, @tagName(output_format) });

    {

        // Parse file header before creating the output file
        var stream = std.io.fixedBufferStream(intermediary_tvg.items);
        var parser = try tvg.parse(allocator, stream.reader());
        defer parser.deinit();

        // Open/create the output file after the TVG header was valid
        var output_stream = try FileOrStream.openWrite(std.fs.cwd(), output_file);
        defer output_stream.close();

        switch (output_format) {
            .tvg => {
                try output_stream.writer().writeAll(intermediary_tvg.items);
            },
            .tvgt => {
                try tvg.text.renderStream(&parser, output_stream.writer());
            },
            .svg => {
                try tvg.svg.renderStream(allocator, &parser, output_stream.writer());
            },
        }
    }
    return 0;
}

const FileOrStream = struct {
    file: std.fs.File,
    close_stream: bool,

    fn openRead(dir: std.fs.Dir, path: []const u8) !FileOrStream {
        if (std.mem.eql(u8, path, "-")) {
            return FileOrStream{
                .file = std.io.getStdIn(),
                .close_stream = false,
            };
        }
        return FileOrStream{
            .file = try dir.openFile(path, .{}),
            .close_stream = true,
        };
    }

    fn openWrite(dir: std.fs.Dir, path: []const u8) !FileOrStream {
        if (std.mem.eql(u8, path, "-")) {
            return FileOrStream{
                .file = std.io.getStdOut(),
                .close_stream = false,
            };
        }
        return FileOrStream{
            .file = try dir.createFile(path, .{}),
            .close_stream = true,
        };
    }

    fn reader(self: *FileOrStream) std.fs.File.Reader {
        return self.file.reader();
    }

    fn writer(self: *FileOrStream) std.fs.File.Writer {
        return self.file.writer();
    }

    fn close(self: *FileOrStream) void {
        if (self.close_stream) {
            self.file.close();
        }
        self.* = undefined;
    }
};
