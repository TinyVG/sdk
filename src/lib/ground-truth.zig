const std = @import("std");
const tvg = @import("tinyvg.zig");

// pub const everything_16 = blk: {
//     @setEvalBranchQuota(100_000);
//     comptime var buf: [2048]u8 = undefined;
//     var stream = std.io.fixedBufferStream(&buf);
//     writeEverything(stream.writer(), .default) catch unreachable;
//     break :blk stream.getWritten();
// };

pub fn main() !void {
    // try std.fs.cwd().writeFile("examples/app_menu.tvg", &app_menu);
    // try std.fs.cwd().writeFile("examples/workspace.tvg", &workspace);
    // try std.fs.cwd().writeFile("examples/workspace_add.tvg", &workspace_add);
    {
        var file = try std.fs.cwd().createFile("shield-8.tvg", .{});
        defer file.close();

        var writer = tvg.builder.create(file.writer());
        try writer.writeHeader(24, 24, .@"1/4", .u8888, .reduced);

        try renderShield(&writer);
    }
    {
        var file = try std.fs.cwd().createFile("shield-16.tvg", .{});
        defer file.close();

        var writer = tvg.builder.create(file.writer());
        try writer.writeHeader(24, 24, .@"1/32", .u8888, .default);

        try renderShield(&writer);
    }
    {
        var file = try std.fs.cwd().createFile("shield-32.tvg", .{});
        defer file.close();

        var writer = tvg.builder.create(file.writer());
        try writer.writeHeader(24, 24, .@"1/2048", .u8888, .enhanced);

        try renderShield(&writer);
    }
    // try std.fs.cwd().writeFile("examples/arc-variants.tvg", &arc_variants);
    // try std.fs.cwd().writeFile("examples/feature-showcase.tvg", &feature_showcase);

    {
        var file = try std.fs.cwd().createFile("everything.tvg", .{});
        defer file.close();

        try writeEverything(file.writer(), .default);
    }

    {
        var file = try std.fs.cwd().createFile("everything-32.tvg", .{});
        defer file.close();

        try writeEverything(file.writer(), .enhanced);
    }
}

/// This function renders a new
pub fn writeEverything(src_writer: anytype, range: tvg.Range) !void {
    var writer = tvg.builder.create(src_writer);
    const Writer = @TypeOf(writer);

    const padding = 25;
    const Emitter = struct {
        const width = 100;

        fn emitFillPolygon(w: *Writer, dx: f32, dy: f32, style: tvg.Style) !f32 {
            try w.writeFillPolygon(
                style,
                &[_]tvg.Point{
                    tvg.point(dx, dy),
                    tvg.point(dx + width, dy + 10),
                    tvg.point(dx + 10, dy + 20),
                    tvg.point(dx + width, dy + 30),
                    tvg.point(dx, dy + 40),
                },
            );
            return 40;
        }

        fn emitOutlineFillPolygon(w: *Writer, dx: f32, dy: f32, style: tvg.Style) !f32 {
            try w.writeOutlineFillPolygon(
                style,
                tvg.Style{ .flat = 3 },
                2.5,
                &[_]tvg.Point{
                    tvg.point(dx, dy),
                    tvg.point(dx + width, dy + 10),
                    tvg.point(dx + 10, dy + 20),
                    tvg.point(dx + width, dy + 30),
                    tvg.point(dx, dy + 40),
                },
            );
            return 40;
        }

        fn emitFillRectangles(w: *Writer, dx: f32, dy: f32, style: tvg.Style) !f32 {
            try w.writeFillRectangles(style, &[_]tvg.Rectangle{
                tvg.rectangle(dx, dy, width, 15),
                tvg.rectangle(dx, dy + 20, width, 15),
                tvg.rectangle(dx, dy + 40, width, 15),
            });

            return 55;
        }

        fn emitDrawLines(w: *Writer, dx: f32, dy: f32, style: tvg.Style) !f32 {
            try w.writeDrawLines(
                style,
                2.5,
                &[_]tvg.Line{
                    tvg.line(tvg.point(dx, dy), tvg.point(dx + width, dy + 10)),
                    tvg.line(tvg.point(dx, dy + 10), tvg.point(dx + width, dy + 20)),
                    tvg.line(tvg.point(dx, dy + 20), tvg.point(dx + width, dy + 30)),
                    tvg.line(tvg.point(dx, dy + 30), tvg.point(dx + width, dy + 40)),
                },
            );
            return 40;
        }

        fn emitDrawLineLoop(w: *Writer, dx: f32, dy: f32, style: tvg.Style) !f32 {
            try w.writeDrawLineLoop(
                style,
                2.5,
                &[_]tvg.Point{
                    tvg.point(dx, dy),
                    tvg.point(dx + width, dy + 10),
                    tvg.point(dx + 10, dy + 20),
                    tvg.point(dx + width, dy + 30),
                    tvg.point(dx, dy + 40),
                },
            );
            return 40;
        }

        fn emitDrawLineStrip(w: *Writer, dx: f32, dy: f32, style: tvg.Style) !f32 {
            try w.writeDrawLineStrip(
                style,
                2.5,
                &[_]tvg.Point{
                    tvg.point(dx, dy),
                    tvg.point(dx + width, dy + 10),
                    tvg.point(dx + 10, dy + 20),
                    tvg.point(dx + width, dy + 30),
                    tvg.point(dx, dy + 40),
                },
            );
            return 40;
        }

        fn emitOutlineFillRectangles(w: *Writer, dx: f32, dy: f32, style: tvg.Style) !f32 {
            try w.writeOutlineFillRectangles(
                style,
                tvg.Style{ .flat = 3 },
                2.5,
                &[_]tvg.Rectangle{
                    tvg.rectangle(dx, dy, width, 15),
                    tvg.rectangle(dx, dy + 20, width, 15),
                    tvg.rectangle(dx, dy + 40, width, 15),
                },
            );

            return 55;
        }

        fn emitDrawPath(w: *Writer, x: f32, y: f32, style: tvg.Style) !f32 {
            const Node = tvg.Path.Node;
            try w.writeDrawPath(style, 3.5, &[_]tvg.Path.Segment{
                tvg.Path.Segment{
                    .start = tvg.point(x, y),
                    .commands = &[_]Node{
                        Node{ .horiz = .{ .line_width = 3.5, .data = x + 10 } }, // H 10
                        Node{ .vert = .{ .line_width = 3.5, .data = y + 10 } }, // V 10
                        Node{ .horiz = .{ .line_width = 3.5, .data = x + 20 } }, // H 20
                        Node{ .line = .{ .line_width = 1.5, .data = tvg.point(x + 100, y) } }, // L 100 1
                        Node{ .bezier = .{ .line_width = 2.5, .data = .{ .c0 = tvg.point(x + 75, y + 20), .c1 = tvg.point(x + 90, y + 50), .p1 = tvg.point(x + 75, y + 50) } } }, // C 75 20 91 50 75 50
                        Node{ .quadratic_bezier = .{ .line_width = 4.5, .data = .{ .c = tvg.point(x + 50, y + 50), .p1 = tvg.point(x + 50, y + 25) } } }, // Q 50 50 50 25
                        Node{ .arc_ellipse = .{ .line_width = 2.5, .data = .{ .radius_x = 35.0, .radius_y = 50.0, .rotation = 1.5, .large_arc = false, .sweep = true, .target = tvg.point(x + 25, y + 35) } } }, // A 0.7 1 20 0 0 25 35
                        Node{ .arc_circle = .{ .line_width = 1.5, .data = .{ .radius = 14.0, .large_arc = false, .sweep = false, .target = tvg.point(x, y + 25) } } }, // A 1 1 0 0 1 0 35
                        Node{ .close = .{ .line_width = 3.5, .data = {} } }, // Z
                    },
                },
            });
            return 50;
        }
        fn emitFillPath(w: *Writer, x: f32, y: f32, style: tvg.Style) !f32 {
            const Node = tvg.Path.Node;
            try w.writeFillPath(style, &[_]tvg.Path.Segment{
                tvg.Path.Segment{
                    .start = tvg.point(x, y),
                    .commands = &[_]Node{
                        Node{ .horiz = .{ .data = x + 10 } }, // H 10
                        Node{ .vert = .{ .data = y + 10 } }, // V 10
                        Node{ .horiz = .{ .data = x + 20 } }, // H 20
                        Node{ .line = .{ .data = tvg.point(x + 100, y) } }, // L 100 1
                        Node{ .bezier = .{ .data = .{ .c0 = tvg.point(x + 75, y + 20), .c1 = tvg.point(x + 90, y + 50), .p1 = tvg.point(x + 75, y + 50) } } }, // C 75 20 91 50 75 50
                        Node{ .quadratic_bezier = .{ .data = .{ .c = tvg.point(x + 50, y + 50), .p1 = tvg.point(x + 50, y + 25) } } }, // Q 50 50 50 25
                        Node{ .arc_ellipse = .{ .data = .{ .radius_x = 35.0, .radius_y = 50.0, .rotation = 1.5, .large_arc = false, .sweep = true, .target = tvg.point(x + 25, y + 35) } } }, // A 0.7 1 20 0 0 25 35
                        Node{ .arc_circle = .{ .data = .{ .radius = 14.0, .large_arc = false, .sweep = false, .target = tvg.point(x, y + 25) } } }, // A 1 1 0 0 1 0 35
                        Node{ .close = .{ .data = {} } }, // Z
                    },
                },
            });
            return 50;
        }
        fn emitOutlineFillPath(w: *Writer, x: f32, y: f32, style: tvg.Style) !f32 {
            const Node = tvg.Path.Node;
            try w.writeOutlineFillPath(style, tvg.Style{ .flat = 3 }, 2.5, &[_]tvg.Path.Segment{
                tvg.Path.Segment{
                    .start = tvg.point(x, y),
                    .commands = &[_]Node{
                        Node{ .horiz = .{ .data = x + 10 } }, // H 10
                        Node{ .vert = .{ .data = y + 10 } }, // V 10
                        Node{ .horiz = .{ .data = x + 20 } }, // H 20
                        Node{ .line = .{ .data = tvg.point(x + 100, y) } }, // L 100 1
                        Node{ .bezier = .{ .data = .{ .c0 = tvg.point(x + 75, y + 20), .c1 = tvg.point(x + 90, y + 50), .p1 = tvg.point(x + 75, y + 50) } } }, // C 75 20 91 50 75 50
                        Node{ .quadratic_bezier = .{ .data = .{ .c = tvg.point(x + 50, y + 50), .p1 = tvg.point(x + 50, y + 25) } } }, // Q 50 50 50 25
                        Node{ .arc_ellipse = .{ .data = .{ .radius_x = 35.0, .radius_y = 50.0, .rotation = 1.5, .large_arc = false, .sweep = true, .target = tvg.point(x + 25, y + 35) } } }, // A 0.7 1 20 0 0 25 35
                        Node{ .arc_circle = .{ .data = .{ .radius = 14.0, .large_arc = false, .sweep = false, .target = tvg.point(x, y + 25) } } }, // A 1 1 0 0 1 0 35
                        Node{ .close = .{ .data = {} } }, // Z
                    },
                },
            });
            return 50;
        }
    };

    const items = [_]fn (*Writer, f32, f32, tvg.Style) Writer.Error!f32{
        Emitter.emitFillRectangles,
        Emitter.emitOutlineFillRectangles,
        Emitter.emitDrawLines,
        Emitter.emitDrawLineLoop,
        Emitter.emitDrawLineStrip,
        Emitter.emitFillPolygon,
        Emitter.emitOutlineFillPolygon,
        Emitter.emitDrawPath,
        Emitter.emitFillPath,
        Emitter.emitOutlineFillPath,
    };

    const style_base = [_]tvg.Style{
        tvg.Style{ .flat = 0 },
        tvg.Style{ .linear = .{
            .point_0 = tvg.point(0, 0),
            .point_1 = tvg.point(Emitter.width, 50),
            .color_0 = 1,
            .color_1 = 2,
        } },
        tvg.Style{ .radial = .{
            .point_0 = tvg.point(50, 25),
            .point_1 = tvg.point(Emitter.width, 50),
            .color_0 = 1,
            .color_1 = 2,
        } },
    };

    try writer.writeHeader(3 * Emitter.width + 4 * padding, 768, .@"1/32", .u8888, range);
    try writer.writeColorTable(&[_]tvg.Color{
        try tvg.Color.fromString("e7a915"), // 0 yellow
        try tvg.Color.fromString("ff7800"), // 1 orange
        try tvg.Color.fromString("40ff00"), // 2 green
        try tvg.Color.fromString("ba004d"), // 3 reddish purple
        try tvg.Color.fromString("62009e"), // 4 blueish purple
        try tvg.Color.fromString("94e538"), // 5 grass green
    });

    var dx: f32 = padding;
    for (style_base) |style_example| {
        var dy: f32 = padding;

        inline for (items) |item| {
            var style = style_example;
            switch (style) {
                .flat => {},
                .linear, .radial => |*grad| {
                    grad.point_0.x += dx;
                    grad.point_0.y += dy;
                    grad.point_1.x += dx;
                    grad.point_1.y += dy;
                },
            }

            const height = try item(&writer, dx, dy, style);
            dy += (height + padding);
        }

        dx += (Emitter.width + padding);
    }

    try writer.writeEndOfFile();
}

pub fn renderShield(writer: anytype) !void {
    const Node = tvg.Path.Node;

    // header is already written here

    try writer.writeColorTable(&[_]tvg.Color{
        try tvg.Color.fromString("29adff"),
        try tvg.Color.fromString("fff1e8"),
    });

    try writer.writeFillPath(
        tvg.Style{ .flat = 0 },
        &[_]tvg.Path.Segment{
            tvg.Path.Segment{
                .start = tvg.Point{ .x = 12, .y = 1 },
                .commands = &[_]Node{
                    Node{ .line = .{ .data = tvg.point(3, 5) } },
                    Node{ .vert = .{ .data = 11 } },
                    Node{ .bezier = .{ .data = Node.Bezier{ .c0 = tvg.point(3, 16.55), .c1 = tvg.point(6.84, 21.74), .p1 = tvg.point(12, 23) } } },
                    Node{ .bezier = .{ .data = Node.Bezier{ .c0 = tvg.point(17.16, 21.74), .c1 = tvg.point(21, 16.55), .p1 = tvg.point(21, 11) } } },
                    Node{ .vert = .{ .data = 5 } },
                },
            },
            tvg.Path.Segment{
                .start = tvg.Point{ .x = 17.13, .y = 17 },
                .commands = &[_]Node{
                    Node{ .bezier = .{ .data = Node.Bezier{ .c0 = tvg.point(15.92, 18.85), .c1 = tvg.point(14.11, 20.24), .p1 = tvg.point(12, 20.92) } } },
                    Node{ .bezier = .{ .data = Node.Bezier{ .c0 = tvg.point(9.89, 20.24), .c1 = tvg.point(8.08, 18.85), .p1 = tvg.point(6.87, 17) } } },
                    Node{ .bezier = .{ .data = Node.Bezier{ .c0 = tvg.point(6.53, 16.5), .c1 = tvg.point(6.24, 16), .p1 = tvg.point(6, 15.47) } } },
                    Node{ .bezier = .{ .data = Node.Bezier{ .c0 = tvg.point(6, 13.82), .c1 = tvg.point(8.71, 12.47), .p1 = tvg.point(12, 12.47) } } },
                    Node{ .bezier = .{ .data = Node.Bezier{ .c0 = tvg.point(15.29, 12.47), .c1 = tvg.point(18, 13.79), .p1 = tvg.point(18, 15.47) } } },
                    Node{ .bezier = .{ .data = Node.Bezier{ .c0 = tvg.point(17.76, 16), .c1 = tvg.point(17.47, 16.5), .p1 = tvg.point(17.13, 17) } } },
                },
            },
            tvg.Path.Segment{
                .start = tvg.Point{ .x = 12, .y = 5 },
                .commands = &[_]Node{
                    Node{ .bezier = .{ .data = Node.Bezier{ .c0 = tvg.point(13.5, 5), .c1 = tvg.point(15, 6.2), .p1 = tvg.point(15, 8) } } },
                    Node{ .bezier = .{ .data = Node.Bezier{ .c0 = tvg.point(15, 9.5), .c1 = tvg.point(13.8, 10.998), .p1 = tvg.point(12, 11) } } },
                    Node{ .bezier = .{ .data = Node.Bezier{ .c0 = tvg.point(10.5, 11), .c1 = tvg.point(9, 9.8), .p1 = tvg.point(9, 8) } } },
                    Node{ .bezier = .{ .data = Node.Bezier{ .c0 = tvg.point(9, 6.4), .c1 = tvg.point(10.2, 5), .p1 = tvg.point(12, 5) } } },
                },
            },
        },
    );

    try writer.writeEndOfFile();
}

// const builder = tvg.comptime_builder(.@"1/256", .default);
// const builder_16 = tvg.comptime_builder(.@"1/16", .default);

// pub const app_menu = blk: {
//     @setEvalBranchQuota(10_000);

//     break :blk builder.header(48, 48) ++
//         builder.colorTable(&[_]tvg.Color{
//         tvg.Color.fromString("000000") catch unreachable,
//     }) ++
//         builder.fillRectangles(3, .flat, 0) ++
//         builder.rectangle(6, 12, 36, 4) ++
//         builder.rectangle(6, 22, 36, 4) ++
//         builder.rectangle(6, 32, 36, 4) ++
//         builder.end_of_document;
// };

// pub const workspace = blk: {
//     @setEvalBranchQuota(10_000);

//     break :blk builder.header(48, 48) ++
//         builder.colorTable(&[_]tvg.Color{
//         tvg.Color.fromString("008751") catch unreachable,
//         tvg.Color.fromString("83769c") catch unreachable,
//         tvg.Color.fromString("1d2b53") catch unreachable,
//     }) ++
//         builder.fillRectangles(1, .flat, 0) ++
//         builder.rectangle(6, 6, 16, 36) ++
//         builder.fillRectangles(1, .flat, 1) ++
//         builder.rectangle(26, 6, 16, 16) ++
//         builder.fillRectangles(1, .flat, 2) ++
//         builder.rectangle(26, 26, 16, 16) ++
//         builder.end_of_document;
// };

// pub const workspace_add = blk: {
//     @setEvalBranchQuota(10_000);

//     break :blk builder.header(48, 48) ++
//         builder.colorTable(&[_]tvg.Color{
//         tvg.Color.fromString("008751") catch unreachable,
//         tvg.Color.fromString("83769c") catch unreachable,
//         tvg.Color.fromString("ff004d") catch unreachable,
//     }) ++
//         builder.fillRectangles(1, .flat, 0) ++
//         builder.rectangle(6, 6, 16, 36) ++
//         builder.fillRectangles(1, .flat, 1) ++
//         builder.rectangle(26, 6, 16, 16) ++
//         builder.fillPath(1, .flat, 2) ++
//         builder.uint(11) ++
//         builder.point(26, 32) ++
//         builder.path.horiz(32) ++
//         builder.path.vert(26) ++
//         builder.path.horiz(36) ++
//         builder.path.vert(32) ++
//         builder.path.horiz(42) ++
//         builder.path.vert(36) ++
//         builder.path.horiz(36) ++
//         builder.path.vert(42) ++
//         builder.path.horiz(32) ++
//         builder.path.vert(36) ++
//         builder.path.horiz(26) ++
//         builder.end_of_document;
// };

// fn makeShield(comptime b: type) type {
//     @setEvalBranchQuota(10_000);

//     const icon = b.header(24, 24) ++
//         b.colorTable(&[_]tvg.Color{
//         tvg.Color.fromString("29adff") catch unreachable,
//         tvg.Color.fromString("fff1e8") catch unreachable,
//     }) ++
//         // tests even_odd rule
//         b.fillPath(3, .flat, 0) ++
//         b.uint(5) ++ // 0
//         b.uint(6) ++ // 1
//         b.uint(4) ++ // 2
//         b.point(12, 1) ++ // M 12 1
//         b.path.line(3, 5) ++ // L 3 5
//         b.path.vert(11) ++ // V 11
//         b.path.bezier(3, 16.55, 6.84, 21.74, 12, 23) ++ // C 3     16.55 6.84 21.74 12 23
//         b.path.bezier(17.16, 21.74, 21, 16.55, 21, 11) ++ // C 17.16 21.74 21   16.55 21 11
//         b.path.vert(5) ++ // V 5
//         // b.fillPath(1, .flat, 1) ++
//         // b.uint(6) ++
//         b.point(17.13, 17) ++ // M 12 1
//         b.path.bezier(15.92, 18.85, 14.11, 20.24, 12, 20.92) ++
//         b.path.bezier(9.89, 20.24, 8.08, 18.85, 6.87, 17) ++
//         b.path.bezier(6.53, 16.5, 6.24, 16, 6, 15.47) ++
//         b.path.bezier(6, 13.82, 8.71, 12.47, 12, 12.47) ++
//         b.path.bezier(15.29, 12.47, 18, 13.79, 18, 15.47) ++
//         b.path.bezier(17.76, 16, 17.47, 16.5, 17.13, 17) ++
//         // b.fillPath(1, .flat, 1) ++
//         // b.uint(4) ++
//         b.point(12, 5) ++
//         b.path.bezier(13.5, 5, 15, 6.2, 15, 8) ++
//         b.path.bezier(15, 9.5, 13.8, 10.998, 12, 11) ++
//         b.path.bezier(10.5, 11, 9, 9.8, 9, 8) ++
//         b.path.bezier(9, 6.4, 10.2, 5, 12, 5) ++
//         b.end_of_document;
//     return struct {
//         const data = icon;
//     };
// }

// pub const shield = makeShield(builder).data;

// pub const shield_8 = makeShield(tvg.comptime_builder(.@"1/4", .reduced)).data;

// pub const shield_32 = makeShield(tvg.comptime_builder(.@"1/2048", .enhanced)).data;

// pub const arc_variants = builder.header(92, 92) ++
//     builder.colorTable(&[_]tvg.Color{tvg.Color.fromString("40ff00") catch unreachable}) ++
//     builder.fillPath(1, .flat, 0) ++
//     builder.uint(8) ++
//     builder.point(48, 32) ++
//     builder.path.horiz(64) ++
//     builder.path.arc_ellipse(18.5, 18.5, 0, false, true, 80, 48) ++
//     builder.path.vert(64) ++
//     builder.path.arc_ellipse(18.5, 18.5, 0, false, false, 64, 80) ++
//     builder.path.horiz(48) ++
//     builder.path.arc_ellipse(18.5, 18.5, 0, true, true, 32, 64) ++
//     builder.path.vert(64) ++
//     builder.path.arc_ellipse(18.5, 18.5, 0, true, false, 48, 32) ++
//     builder.end_of_document;

// pub const feature_showcase = blk: {
//     @setEvalBranchQuota(20_000);
//     break :blk builder_16.header(1024, 1024) ++
//         builder_16.colorTable(&[_]tvg.Color{
//         tvg.Color.fromString("e7a915") catch unreachable, // 0 yellow
//         tvg.Color.fromString("ff7800") catch unreachable, // 1 orange
//         tvg.Color.fromString("40ff00") catch unreachable, // 2 green
//         tvg.Color.fromString("ba004d") catch unreachable, // 3 reddish purple
//         tvg.Color.fromString("62009e") catch unreachable, // 4 blueish purple
//         tvg.Color.fromString("94e538") catch unreachable, // 5 grass green
//     }) ++
//         // FILL RECTANGLE
//         builder_16.fillRectangles(2, .flat, 0) ++
//         builder_16.rectangle(16, 16, 64, 48) ++
//         builder_16.rectangle(96, 16, 64, 48) ++
//         builder_16.fillRectangles(2, .linear, .{
//         .point_0 = .{ .x = 32, .y = 80 },
//         .point_1 = .{ .x = 144, .y = 128 },
//         .color_0 = 1,
//         .color_1 = 2,
//     }) ++
//         builder_16.rectangle(16, 80, 64, 48) ++
//         builder_16.rectangle(96, 80, 64, 48) ++
//         builder_16.fillRectangles(2, .radial, .{
//         .point_0 = .{ .x = 80, .y = 144 },
//         .point_1 = .{ .x = 48, .y = 176 },
//         .color_0 = 1,
//         .color_1 = 2,
//     }) ++
//         builder_16.rectangle(16, 144, 64, 48) ++
//         builder_16.rectangle(96, 144, 64, 48) ++
//         // FILL POLYGON
//         builder_16.fillPolygon(7, .flat, 3) ++
//         builder_16.point(192, 32) ++
//         builder_16.point(208, 16) ++
//         builder_16.point(240, 16) ++
//         builder_16.point(256, 32) ++
//         builder_16.point(256, 64) ++
//         builder_16.point(224, 48) ++
//         builder_16.point(192, 64) ++
//         builder_16.fillPolygon(7, .linear, .{
//         .point_0 = .{ .x = 224, .y = 80 },
//         .point_1 = .{ .x = 224, .y = 128 },
//         .color_0 = 3,
//         .color_1 = 4,
//     }) ++
//         builder_16.point(192, 96) ++
//         builder_16.point(208, 80) ++
//         builder_16.point(240, 80) ++
//         builder_16.point(256, 96) ++
//         builder_16.point(256, 128) ++
//         builder_16.point(224, 112) ++
//         builder_16.point(192, 128) ++
//         builder_16.fillPolygon(7, .radial, .{
//         .point_0 = .{ .x = 224, .y = 144 },
//         .point_1 = .{ .x = 224, .y = 192 },
//         .color_0 = 3,
//         .color_1 = 4,
//     }) ++
//         builder_16.point(192, 160) ++
//         builder_16.point(208, 144) ++
//         builder_16.point(240, 144) ++
//         builder_16.point(256, 160) ++
//         builder_16.point(256, 192) ++
//         builder_16.point(224, 176) ++
//         builder_16.point(192, 192) ++
//         // FILL PATH
//         builder_16.fillPath(1, .flat, 5) ++
//         builder.uint(10) ++
//         builder_16.point(288, 64) ++
//         builder_16.path.vert(32) ++
//         builder_16.path.bezier(288, 24, 288, 16, 304, 16) ++
//         builder_16.path.horiz(336) ++
//         builder_16.path.bezier(352, 16, 352, 24, 352, 32) ++
//         builder_16.path.vert(64) ++
//         builder_16.path.line(336, 48) ++ // this should be an arc segment
//         builder_16.path.line(320, 32) ++
//         builder_16.path.line(312, 48) ++
//         builder_16.path.line(304, 64) ++ // this should be an arc segment
//         builder_16.path.close() ++
//         builder_16.fillPath(1, .linear, .{
//         .point_0 = .{ .x = 320, .y = 80 },
//         .point_1 = .{ .x = 320, .y = 128 },
//         .color_0 = 3,
//         .color_1 = 4,
//     }) ++
//         builder.uint(10) ++
//         builder_16.point(288, 64 + 64) ++
//         builder_16.path.vert(64 + 32) ++
//         builder_16.path.bezier(288, 64 + 24, 288, 64 + 16, 304, 64 + 16) ++
//         builder_16.path.horiz(336) ++
//         builder_16.path.bezier(352, 64 + 16, 352, 64 + 24, 352, 64 + 32) ++
//         builder_16.path.vert(64 + 64) ++
//         builder_16.path.line(336, 64 + 48) ++ // this should be an arc segment
//         builder_16.path.line(320, 64 + 32) ++
//         builder_16.path.line(312, 64 + 48) ++
//         builder_16.path.line(304, 64 + 64) ++ // this should be an arc segment
//         builder_16.path.close() ++
//         builder_16.fillPath(1, .radial, .{
//         .point_0 = .{ .x = 320, .y = 144 },
//         .point_1 = .{ .x = 320, .y = 192 },
//         .color_0 = 3,
//         .color_1 = 4,
//     }) ++
//         builder.uint(10) ++
//         builder_16.point(288, 128 + 64) ++
//         builder_16.path.vert(128 + 32) ++
//         builder_16.path.bezier(288, 128 + 24, 288, 128 + 16, 304, 128 + 16) ++
//         builder_16.path.horiz(336) ++
//         builder_16.path.bezier(352, 128 + 16, 352, 128 + 24, 352, 128 + 32) ++
//         builder_16.path.vert(128 + 64) ++
//         builder_16.path.line(336, 128 + 48) ++ // this should be an arc segment
//         builder_16.path.line(320, 128 + 32) ++
//         builder_16.path.line(312, 128 + 48) ++
//         builder_16.path.line(304, 128 + 64) ++ // this should be an arc segment
//         builder_16.path.close() ++
//         // DRAW LINES
//         builder_16.drawLines(4, 0.0, .flat, 1) ++
//         builder_16.point(16 + 0, 224 + 0) ++ builder_16.point(16 + 64, 224 + 0) ++
//         builder_16.point(16 + 0, 224 + 16) ++ builder_16.point(16 + 64, 224 + 16) ++
//         builder_16.point(16 + 0, 224 + 32) ++ builder_16.point(16 + 64, 224 + 32) ++
//         builder_16.point(16 + 0, 224 + 48) ++ builder_16.point(16 + 64, 224 + 48) ++
//         builder_16.drawLines(4, 3.0, .linear, .{
//         .point_0 = .{ .x = 48, .y = 304 },
//         .point_1 = .{ .x = 48, .y = 352 },
//         .color_0 = 3,
//         .color_1 = 4,
//     }) ++
//         builder_16.point(16 + 0, 304 + 0) ++ builder_16.point(16 + 64, 304 + 0) ++
//         builder_16.point(16 + 0, 304 + 16) ++ builder_16.point(16 + 64, 304 + 16) ++
//         builder_16.point(16 + 0, 304 + 32) ++ builder_16.point(16 + 64, 304 + 32) ++
//         builder_16.point(16 + 0, 304 + 48) ++ builder_16.point(16 + 64, 304 + 48) ++
//         builder_16.drawLines(4, 6.0, .radial, .{
//         .point_0 = .{ .x = 48, .y = 408 },
//         .point_1 = .{ .x = 48, .y = 432 },
//         .color_0 = 3,
//         .color_1 = 4,
//     }) ++
//         builder_16.point(16 + 0, 384 + 0) ++ builder_16.point(16 + 64, 384 + 0) ++
//         builder_16.point(16 + 0, 384 + 16) ++ builder_16.point(16 + 64, 384 + 16) ++
//         builder_16.point(16 + 0, 384 + 32) ++ builder_16.point(16 + 64, 384 + 32) ++
//         builder_16.point(16 + 0, 384 + 48) ++ builder_16.point(16 + 64, 384 + 48) ++
//         // DRAW LINE STRIP
//         builder_16.drawLineStrip(8, 3.0, .flat, 1) ++
//         builder_16.point(96 + 0, 224 + 0) ++
//         builder_16.point(96 + 64, 224 + 0) ++
//         builder_16.point(96 + 64, 224 + 16) ++
//         builder_16.point(96 + 0, 224 + 16) ++
//         builder_16.point(96 + 0, 224 + 32) ++
//         builder_16.point(96 + 64, 224 + 32) ++
//         builder_16.point(96 + 64, 224 + 48) ++
//         builder_16.point(96 + 0, 224 + 48) ++
//         builder_16.drawLineStrip(8, 6.0, .linear, .{
//         .point_0 = .{ .x = 128, .y = 304 },
//         .point_1 = .{ .x = 128, .y = 352 },
//         .color_0 = 3,
//         .color_1 = 4,
//     }) ++
//         builder_16.point(96 + 0, 304 + 0) ++
//         builder_16.point(96 + 64, 304 + 0) ++
//         builder_16.point(96 + 64, 304 + 16) ++
//         builder_16.point(96 + 0, 304 + 16) ++
//         builder_16.point(96 + 0, 304 + 32) ++
//         builder_16.point(96 + 64, 304 + 32) ++
//         builder_16.point(96 + 64, 304 + 48) ++
//         builder_16.point(96 + 0, 304 + 48) ++
//         builder_16.drawLineStrip(8, 0.0, .radial, .{
//         .point_0 = .{ .x = 128, .y = 408 },
//         .point_1 = .{ .x = 128, .y = 432 },
//         .color_0 = 3,
//         .color_1 = 4,
//     }) ++
//         builder_16.point(96 + 0, 384 + 0) ++
//         builder_16.point(96 + 64, 384 + 0) ++
//         builder_16.point(96 + 64, 384 + 16) ++
//         builder_16.point(96 + 0, 384 + 16) ++
//         builder_16.point(96 + 0, 384 + 32) ++
//         builder_16.point(96 + 64, 384 + 32) ++
//         builder_16.point(96 + 64, 384 + 48) ++
//         builder_16.point(96 + 0, 384 + 48) ++
//         // DRAW LINE LOOP
//         builder_16.drawLineLoop(8, 6.0, .flat, 1) ++
//         builder_16.point(176 + 0, 224 + 0) ++
//         builder_16.point(176 + 64, 224 + 0) ++
//         builder_16.point(176 + 64, 224 + 16) ++
//         builder_16.point(176 + 16, 224 + 16) ++
//         builder_16.point(176 + 16, 224 + 32) ++
//         builder_16.point(176 + 64, 224 + 32) ++
//         builder_16.point(176 + 64, 224 + 48) ++
//         builder_16.point(176 + 0, 224 + 48) ++
//         builder_16.drawLineLoop(8, 0.0, .linear, .{
//         .point_0 = .{ .x = 208, .y = 304 },
//         .point_1 = .{ .x = 208, .y = 352 },
//         .color_0 = 3,
//         .color_1 = 4,
//     }) ++
//         builder_16.point(176 + 0, 304 + 0) ++
//         builder_16.point(176 + 64, 304 + 0) ++
//         builder_16.point(176 + 64, 304 + 16) ++
//         builder_16.point(176 + 16, 304 + 16) ++
//         builder_16.point(176 + 16, 304 + 32) ++
//         builder_16.point(176 + 64, 304 + 32) ++
//         builder_16.point(176 + 64, 304 + 48) ++
//         builder_16.point(176 + 0, 304 + 48) ++
//         builder_16.drawLineLoop(8, 3.0, .radial, .{
//         .point_0 = .{ .x = 208, .y = 408 },
//         .point_1 = .{ .x = 208, .y = 432 },
//         .color_0 = 3,
//         .color_1 = 4,
//     }) ++
//         builder_16.point(176 + 0, 384 + 0) ++
//         builder_16.point(176 + 64, 384 + 0) ++
//         builder_16.point(176 + 64, 384 + 16) ++
//         builder_16.point(176 + 16, 384 + 16) ++
//         builder_16.point(176 + 16, 384 + 32) ++
//         builder_16.point(176 + 64, 384 + 32) ++
//         builder_16.point(176 + 64, 384 + 48) ++
//         builder_16.point(176 + 0, 384 + 48) ++
//         // DRAW LINE PATH
//         builder_16.drawPath(1, 0.0, .flat, 1) ++
//         builder.uint(10) ++
//         builder_16.point(256 + 0, 224 + 0) ++
//         builder_16.path.horiz(256 + 48) ++
//         builder_16.path.bezier(256 + 64, 224 + 0, 256 + 64, 224 + 16, 256 + 48, 224 + 16) ++
//         builder_16.path.horiz(256 + 32) ++
//         builder_16.path.line(256 + 16, 224 + 24) ++
//         builder_16.path.line(256 + 32, 224 + 32) ++
//         builder_16.path.line(256 + 64, 224 + 32) ++ // this is arc-ellipse later
//         builder_16.path.line(256 + 48, 224 + 48) ++ // this is arc-circle later
//         builder_16.path.horiz(256 + 16) ++
//         builder_16.path.line(256 + 0, 224 + 32) ++ // this is arc-circle later
//         builder_16.path.close() ++
//         builder_16.drawPath(1, 6.0, .linear, .{
//         .point_0 = .{ .x = 288, .y = 408 },
//         .point_1 = .{ .x = 288, .y = 432 },
//         .color_0 = 3,
//         .color_1 = 4,
//     }) ++
//         builder.uint(10) ++
//         builder_16.point(256 + 0, 304 + 0) ++
//         builder_16.path.horiz(256 + 48) ++
//         builder_16.path.bezier(256 + 64, 304 + 0, 256 + 64, 304 + 16, 256 + 48, 304 + 16) ++
//         builder_16.path.horiz(256 + 32) ++
//         builder_16.path.line(256 + 16, 304 + 24) ++
//         builder_16.path.line(256 + 32, 304 + 32) ++
//         builder_16.path.line(256 + 64, 304 + 32) ++ // this is arc-ellipse later
//         builder_16.path.line(256 + 48, 304 + 48) ++ // this is arc-circle later
//         builder_16.path.horiz(256 + 16) ++
//         builder_16.path.line(256 + 0, 304 + 32) ++ // this is arc-circle later
//         builder_16.path.close() ++
//         builder_16.drawPath(1, 3.0, .radial, .{
//         .point_0 = .{ .x = 288, .y = 408 },
//         .point_1 = .{ .x = 288, .y = 432 },
//         .color_0 = 3,
//         .color_1 = 4,
//     }) ++
//         builder.uint(10) ++
//         builder_16.point(256 + 0, 384 + 0) ++
//         builder_16.path.horiz(256 + 48) ++
//         builder_16.path.bezier(256 + 64, 384 + 0, 256 + 64, 384 + 16, 256 + 48, 384 + 16) ++
//         builder_16.path.horiz(256 + 32) ++
//         builder_16.path.line(256 + 16, 384 + 24) ++
//         builder_16.path.line(256 + 32, 384 + 32) ++
//         builder_16.path.line(256 + 64, 384 + 32) ++ // this is arc-ellipse later
//         builder_16.path.line(256 + 48, 384 + 48) ++ // this is arc-circle later
//         builder_16.path.horiz(256 + 16) ++
//         builder_16.path.line(256 + 0, 384 + 32) ++ // this is arc-circle later
//         builder_16.path.close() ++
//         // Outline Fill Rectangle
//         builder_16.outlineFillRectangles(1, 0.0, .flat, 0, .flat, 3) ++
//         builder_16.rectangle(384, 16, 64, 48) ++
//         builder_16.outlineFillRectangles(1, 1.0, .flat, 0, .linear, .{ .point_0 = .{ .x = 416, .y = 80 }, .point_1 = .{ .x = 416, .y = 128 }, .color_0 = 3, .color_1 = 4 }) ++
//         builder_16.rectangle(384, 80, 64, 48) ++
//         builder_16.outlineFillRectangles(1, 2.0, .flat, 0, .radial, .{ .point_0 = .{ .x = 416, .y = 168 }, .point_1 = .{ .x = 416, .y = 216 }, .color_0 = 3, .color_1 = 4 }) ++
//         builder_16.rectangle(384, 144, 64, 48) ++
//         builder_16.outlineFillRectangles(1, 3.0, .linear, .{ .point_0 = .{ .x = 496, .y = 16 }, .point_1 = .{ .x = 496, .y = 64 }, .color_0 = 1, .color_1 = 2 }, .flat, 3) ++
//         builder_16.rectangle(464, 16, 64, 48) ++
//         builder_16.outlineFillRectangles(1, 4.0, .linear, .{ .point_0 = .{ .x = 496, .y = 80 }, .point_1 = .{ .x = 496, .y = 128 }, .color_0 = 1, .color_1 = 2 }, .linear, .{ .point_0 = .{ .x = 496, .y = 80 }, .point_1 = .{ .x = 496, .y = 128 }, .color_0 = 3, .color_1 = 4 }) ++
//         builder_16.rectangle(464, 80, 64, 48) ++
//         builder_16.outlineFillRectangles(1, 5.0, .linear, .{ .point_0 = .{ .x = 496, .y = 144 }, .point_1 = .{ .x = 496, .y = 192 }, .color_0 = 1, .color_1 = 2 }, .radial, .{ .point_0 = .{ .x = 496, .y = 168 }, .point_1 = .{ .x = 496, .y = 216 }, .color_0 = 3, .color_1 = 4 }) ++
//         builder_16.rectangle(464, 144, 64, 48) ++
//         builder_16.outlineFillRectangles(1, 6.0, .radial, .{ .point_0 = .{ .x = 576, .y = 40 }, .point_1 = .{ .x = 576, .y = 88 }, .color_0 = 1, .color_1 = 2 }, .flat, 3) ++
//         builder_16.rectangle(544, 16, 64, 48) ++
//         builder_16.outlineFillRectangles(1, 7.0, .radial, .{ .point_0 = .{ .x = 576, .y = 104 }, .point_1 = .{ .x = 576, .y = 150 }, .color_0 = 1, .color_1 = 2 }, .linear, .{ .point_0 = .{ .x = 576, .y = 80 }, .point_1 = .{ .x = 576, .y = 128 }, .color_0 = 3, .color_1 = 4 }) ++
//         builder_16.rectangle(544, 80, 64, 48) ++
//         builder_16.outlineFillRectangles(1, 8.0, .radial, .{ .point_0 = .{ .x = 576, .y = 168 }, .point_1 = .{ .x = 576, .y = 216 }, .color_0 = 1, .color_1 = 2 }, .radial, .{ .point_0 = .{ .x = 576, .y = 168 }, .point_1 = .{ .x = 576, .y = 216 }, .color_0 = 3, .color_1 = 4 }) ++
//         builder_16.rectangle(544, 144, 64, 48) ++
//         // Outline Fill Polygon
//         // TODO
//         // PATH WITH ARC (ELLIPSE)
//         builder_16.drawPath(1, 2.0, .flat, 1) ++
//         builder.uint(3) ++
//         builder_16.point(16 + 0, 464 + 0) ++
//         builder_16.path.line(16 + 16, 464 + 16) ++
//         builder_16.path.arc_ellipse(25, 45, 15, false, false, 16 + 48, 464 + 48) ++
//         builder_16.path.line(16 + 64, 464 + 64) ++
//         builder_16.drawPath(1, 2.0, .flat, 1) ++
//         builder.uint(3) ++
//         builder_16.point(96 + 0, 464 + 0) ++
//         builder_16.path.line(96 + 16, 464 + 16) ++
//         builder_16.path.arc_ellipse(25, 45, 15, false, true, 96 + 48, 464 + 48) ++
//         builder_16.path.line(96 + 64, 464 + 64) ++
//         builder_16.drawPath(1, 2.0, .flat, 1) ++
//         builder.uint(3) ++
//         builder_16.point(176 + 0, 464 + 0) ++
//         builder_16.path.line(176 + 16, 464 + 16) ++
//         builder_16.path.arc_ellipse(25, 45, -35, true, true, 176 + 48, 464 + 48) ++
//         builder_16.path.line(176 + 64, 464 + 64) ++
//         builder_16.drawPath(1, 2.0, .flat, 1) ++
//         builder.uint(3) ++
//         builder_16.point(256 + 0, 464 + 0) ++
//         builder_16.path.line(256 + 16, 464 + 16) ++
//         builder_16.path.arc_ellipse(25, 45, -35, true, false, 256 + 48, 464 + 48) ++
//         builder_16.path.line(256 + 64, 464 + 64) ++
//         // PATH WITH ARC (CIRCLE)
//         builder_16.drawPath(1, 2.0, .flat, 1) ++
//         builder.uint(3) ++
//         builder_16.point(16 + 0, 560 + 0) ++
//         builder_16.path.line(16 + 16, 560 + 16) ++
//         builder_16.path.arc_circle(30, false, false, 16 + 48, 560 + 48) ++
//         builder_16.path.line(16 + 64, 560 + 64) ++
//         builder_16.drawPath(1, 2.0, .flat, 1) ++
//         builder.uint(3) ++
//         builder_16.point(96 + 0, 560 + 0) ++
//         builder_16.path.line(96 + 16, 560 + 16) ++
//         builder_16.path.arc_circle(30, false, true, 96 + 48, 560 + 48) ++
//         builder_16.path.line(96 + 64, 560 + 64) ++
//         builder_16.drawPath(1, 2.0, .flat, 1) ++
//         builder.uint(3) ++
//         builder_16.point(176 + 0, 560 + 0) ++
//         builder_16.path.line(176 + 16, 560 + 16) ++
//         builder_16.path.arc_circle(30, true, true, 176 + 48, 560 + 48) ++
//         builder_16.path.line(176 + 64, 560 + 64) ++
//         builder_16.drawPath(1, 2.0, .flat, 1) ++
//         builder.uint(3) ++
//         builder_16.point(256 + 0, 560 + 0) ++
//         builder_16.path.line(256 + 16, 560 + 16) ++
//         builder_16.path.arc_circle(30, true, false, 256 + 48, 560 + 48) ++
//         builder_16.path.line(256 + 64, 560 + 64) ++
//         builder_16.end_of_document;
// };
