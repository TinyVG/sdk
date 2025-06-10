// TinyVG Renderer 
// Copyright (C) 2025 by honey the codewitch
// MIT License
// To use, pass am ArrayBuffer with the
// TVG document to tvgDimensions
// or tvgRender. With render,
// you place an empty SVG element, 
// ex: <svg id="..." xmlms="..." />
// and pass the id of it to the render
// method. At that point, the SVG tag
// will be populated and rendered by
// the browser.
const tvgInit = (data, id) => {
    return {
        data: data,
        view: new DataView(data),
        cursor: 0,
        scale: 0,
        color_encoding: 0,
        coord_range: 0,
        width: 0, height: 0,
        colors_size: 0,
        colors: [],
        doc: document.getElementById(id), //SVGSVGElement
        elem: undefined, // SVGElement
        gradIndex: 0
    };
}
const tvgDistance = (pointLhs, pointRhs) => {
    const xd = pointRhs.x - pointLhs.x;
    const yd = pointRhs.y - pointLhs.y;
    return Math.sqrt((xd * xd) + (yd * yd));
}
const tvgAdvCoord = (rangeOrCtx) => {
    let range = rangeOrCtx;
    if (rangeOrCtx.coord_range) {
        range = rangeOrCtx.range;
    }
    switch (range) {
        case 0://"default"
            return 2;
        case 1://"reduced":
            return 1;
        case 2://"extended"
            return 4;
    }
}
const tvgMapZeroToMax = (rangeOrCtx, value) => {
    let range = rangeOrCtx;
    if (rangeOrCtx.coord_range) {
        range = rangeOrCtx.range;
    }
    if (0 == value) {
        switch (range) {
            case 0: //"default"
                return 0xFFFF;
            case 1: //"reduced"
                return 0xFF;
            case 2: //"extended"
                return 0xFFFFFFFF;
        }
        return undefined;
    }
    return value;
}
const tvgReadCoordBI = (range, startIndex, data) => {
    const view = new DataView(data);
    switch (range) {
        case 0: //"default"
            return view.getUint16(startIndex, true);

        case 1: //"reduced"
            return view.getUint8(startIndex);

        case 2: //"extended"
            return view.getUint32(startIndex, true);
    }
    return undefined;
}
const tvgReadCoord = (ctx) => {
    let result = undefined;
    switch (ctx.coord_range) {
        case 0: //"default"
            result = ctx.view.getUint16(ctx.cursor, true);
            ctx.cursor += 2;
            break;
        case 1: //"reduced"
            result = ctx.view.getUint8(ctx.cursor);
            ctx.cursor += 1;
            break;
        case 2: //"extended"
            result = ctx.view.getUint32(ctx.cursor, true);
            ctx.cursor += 4;
            break;
    }
    return result;
}
const tvgReadU32 = (ctx) => {
    let count = 0;
    let result = 0;
    var byte;
    while (true) {
        byte = ctx.view.getUint8(ctx.cursor++);
        const val = (byte & 0x7F) << (7 * count);
        result |= val;
        if ((byte & 0x80) === 0)
            break;
        ++count;
    }
    return result;
}
const tvgDownscaleCoord = (ctx, coord) => {
    const factor = (1) << ctx.scale;
    return coord / factor;
}
const tvgReadUnit = (ctx) => {
    const val = tvgReadCoord(ctx);
    return tvgDownscaleCoord(ctx, val);
}
const tvgReadPoint = (ctx) => {
    const x = tvgReadUnit(ctx);
    const y = tvgReadUnit(ctx);
    return { x: x, y: y };
}
const tvgReadColor = (ctx) => {
    switch (ctx.color_encoding) {
        case 2: { // TVG_COLOR_F32:
            // read four values
            const data = [];
            data.push(ctx.view.getFloat32(ctx.cursor, true)); ctx.cursor += 4;
            data.push(ctx.view.getFloat32(ctx.cursor, true)); ctx.cursor += 4;
            data.push(ctx.view.getFloat32(ctx.cursor, true)); ctx.cursor += 4;
            data.push(ctx.view.getFloat32(ctx.cursor, true)); ctx.cursor += 4;
            return { r: data[0], g: data[1], b: data[2], a: data[3] };
        }
        case 1: { // TVG_COLOR_U565: 
            const data = ctx.view.getUint16(ctx.cursor, true);
            ctx.cursor += 2;
            return {
                r: (data & 0x1F) / 15.0,
                g: ((data >>> 5) & 0x3F) / 31.0,
                b: ((data >>> 11) & 0x1F) / 15.0,
                a: 1.0
            };
        }
        case 0: { // TVG_COLOR_U8888: 
            // read four values
            const data = [];
            data.push(ctx.view.getUint8(ctx.cursor++));
            data.push(ctx.view.getUint8(ctx.cursor++));
            data.push(ctx.view.getUint8(ctx.cursor++));
            data.push(ctx.view.getUint8(ctx.cursor++));
            return { r: data[0] / 255.0, g: data[1] / 255.0, b: data[2] / 255.0, a: data[3] / 255.0 };
        }
        case 3: // TVG_COLOR_CUSTOM
            throw new Error("TinyVG: Custom color table not supported");
        default:
            throw new Error("TinyVG: Invalid color format");
    }
}
const tvgParseGradient = (ctx) => {
    const point0 = tvgReadPoint(ctx);
    const point1 = tvgReadPoint(ctx);
    const color0 = tvgReadU32(ctx);
    const color1 = tvgReadU32(ctx);
    return { point0: point0, point1: point1, color0: color0, color1: color1 };
}
const tvgParseStyle = (ctx, kind) => {
    switch (kind) {
        case 0: // TVG_STYLE_FLAT:
            return { kind: kind, flat: tvgReadU32(ctx) };
        case 1: // TVG_STYLE_LINEAR:
            return { kind: kind, linear: tvgParseGradient(ctx) };
        case 2: //TVG_STYLE_RADIAL:
            return { kind: kind, radial: tvgParseGradient(ctx) };
        default:
            throw new Error("TinyVG: Invalid format parsing style");
    }
}
const tvgParseFillHeader = (ctx, kind) => {
    const u32 = tvgReadU32(ctx);
    const size = u32 + 1;
    //out_header->size = count;
    const style = tvgParseStyle(ctx, kind);
    return { size: size, style: style };
}
const tvgParseLineHeader = (ctx, kind) => {
    const u32 = tvgReadU32(ctx);
    const size = u32 + 1;

    const style = tvgParseStyle(ctx, kind);
    const line_width = tvgReadUnit(ctx);

    return { size: size, style: style, line_width: line_width };
}

const tvgParseLineFillHeader = (ctx, kind) => {

    var d = ctx.view.getUint8(ctx.cursor++);
    const size = (d & 0x3F) + 1;
    const fill_style = tvgParseStyle(ctx, kind);
    const line_style = tvgParseStyle(ctx, (d >>> 6) & 0x03);
    const line_width = tvgReadUnit(ctx);
    return { size: size, fill_style: fill_style, line_style: line_style, line_width: line_width };
}
const tvgParsePathD = (ctx, size) => {
    var st, cur;
    var pt;
    var u32;
    var f32;
    var d;
    let result = "";
    pt = tvgReadPoint(ctx);
    result += `M${pt.x} ${pt.y}`;
    st = pt;
    cur = pt;
    for (let j = 0; j < size; ++j) {
        d = ctx.view.getUint8(ctx.cursor++);
        if (((d >>> 4) & 1) !== 0) { // has line
            tvgReadUnit(ctx); // throw away line width (future use)
        }
        switch (d & 7) {
            case 0: // TVG_PATH_LINE:
                pt = tvgReadPoint(ctx);
                result += ` L${pt.x} ${pt.y}`
                cur = pt;
                break;
            case 1: // TVG_PATH_HLINE:
                pt.x = tvgReadUnit(ctx);;
                pt.y = cur.y;
                result += ` H${pt.x}`;
                cur = pt;
                break;
            case 2: // TVG_PATH_VLINE:
                pt.x = cur.x;
                pt.y = tvgReadUnit(ctx);
                result += ` V${pt.y}`;
                cur = pt;
                break;
            case 3: { // TVG_PATH_CUBIC: 
                const ctrl1 = tvgReadPoint(ctx);
                const ctrl2 = tvgReadPoint(ctx);
                const endp = tvgReadPoint(ctx);
                result += ` C${ctrl1.x} ${ctrl1.y} ${ctrl2.x} ${ctrl2.y} ${endp.x} ${endp.y}`;
                cur = endp;
            } break;
            case 4: { // TVG_PATH_ARC_CIRCLE: {
                d = ctx.view.getUint8(ctx.cursor++);
                const radius = tvgReadUnit(ctx);
                pt = tvgReadPoint(ctx);
                result += ` A${radius} ${radius} 0 ${d & 1} ${1 - ((d >>> 1) & 1)} ${pt.x} ${pt.y}`;
                cur = pt;
            } break;
            case 5: { // TVG_PATH_ARC_ELLIPSE: 
                d = ctx.view.getUint8(ctx.cursor++);
                const radius_x = tvgReadUnit(ctx);
                const radius_y = tvgReadUnit(ctx);
                const rotation = tvgReadUnit(ctx);
                pt = tvgReadPoint(ctx);
                result += ` A${radius_x} ${radius_y} ${rotation} ${d & 1} ${1 - ((d >>> 1) & 1)} ${pt.x} ${pt.y}`;
                cur = pt;
            } break;
            case 6: // TVG_PATH_CLOSE:
                result += ' Z';
                cur = st;
                break;
            case 7: { // TVG_PATH_QUAD:
                const ctrl = tvgReadPoint(ctx);
                const endp = tvgReadPoint(ctx);
                result += ` Q${ctrl.x} ${ctrl.y} ${endp.x} ${endp.y}`
                cur = endp;
            } break;
            default:
                throw new Error("TinyVG: Unrecognized command parsing path");
        }
    }
    return result;
}
const tvgParseRect = (ctx) => {
    const pt = tvgReadPoint(ctx);
    const w = tvgReadUnit(ctx);
    const h = tvgReadUnit(ctx);
    return { x: pt.x, y: pt.y, width: w, height: h };
}
const tvgToHex = (code) => {
    let result = code.toString(16);
    if (result.length === 1) {
        return "0" + result;
    }
    return result;
}
const tvgColorToSvgColorAndOpacity = (col) => {
    return { color: `#${tvgToHex(col.r * 255)}${tvgToHex(col.g * 255)}${tvgToHex(col.b * 255)}`, opacity: col.a };
}
const tvgCreateSvgNode = (n, v) => {
    n = document.createElementNS("http://www.w3.org/2000/svg", n);
    if (v) {
        for (let p in v) {
            n.setAttributeNS(null, p.replace(/[A-Z]/g, function (m, p, o, s) { return "-" + m.toLowerCase(); }), v[p]);
        }
    }
    return n;
}
const tvgAddSvgAttribute = (n, a, v) => {
    n.setAttributeNS(null, a, v);
}
const tvgCreateSvgGradient = (ctx, style) => {
    let da = ctx.doc.getElementsByTagNameNS("http://www.w3.org/2000/svg", "defs");
    var defs;
    if (da.length == 0) {
        defs = tvgCreateSvgNode("defs");
        ctx.doc.prepend(defs);
    } else {
        defs = da[0];
    }
    if (style.kind === 1) {
        const node = tvgCreateSvgNode("linearGradient",
            {
                id: `TvgGradient${ctx.gradIndex + 1}`,
                x1: style.linear.point0.x,
                y1: style.linear.point0.y,
                x2: style.linear.point1.x,
                y2: style.linear.point1.y
            });
        node.setAttributeNS(null, "gradientUnits", "userSpaceOnUse");
        node.setAttributeNS(null, "spreadMethod", "pad");
        let col = tvgColorToSvgColorAndOpacity(ctx.colors[style.linear.color0]);
        const stop1 = tvgCreateSvgNode("stop", { offset: "0%", stopColor: col.color });//, stopOpacity: col.opacity});
        node.appendChild(stop1);
        col = tvgColorToSvgColorAndOpacity(ctx.colors[style.linear.color1]);
        const stop2 = tvgCreateSvgNode("stop", { offset: "100%", stopColor: col.color });//, stopOpacity: col.opacity});
        node.appendChild(stop2);
        defs.appendChild(node);
        ++ctx.gradIndex;
        return node.getAttributeNS(null, "id");
    } else if (style.kind === 2) {
        const r = tvgDistance(style.radial.point0, style.radial.point1);
        const node = tvgCreateSvgNode("radialGradient",
            {
                id: `TvgGradient${ctx.gradIndex + 1}`,
                cx: style.radial.point0.x,
                cy: style.radial.point0.y,
                fx: style.radial.point0.x,
                fy: style.radial.point0.y,
                r: r
            });
        node.setAttributeNS(null, "gradientUnits", "userSpaceOnUse");
        node.setAttributeNS(null, "spreadMethod", "pad");
        let col = tvgColorToSvgColorAndOpacity(ctx.colors[style.radial.color0]);
        const stop1 = tvgCreateSvgNode("stop", { offset: "0%", stopColor: col.color, stopOpacity: col.opacity });
        node.appendChild(stop1);
        col = tvgColorToSvgColorAndOpacity(ctx.colors[style.radial.color1]);
        const stop2 = tvgCreateSvgNode("stop", { offset: "100%", stopColor: col.color, stopOpacity: col.opacity });
        node.appendChild(stop2);
        defs.appendChild(node);
        ++ctx.gradIndex;
        return node.getAttributeNS(null, "id");
    } else if (style.kind === 0) throw new Error("TinyVG: attempt to pass flat style to create gradient");
    else throw new Error("TinyVG: attempt to pass an invalid style to create gradient");
}
const tvgApplyStyle = (ctx, style, isFill) => {
    if (style.kind === 0) { // flat
        const col = tvgColorToSvgColorAndOpacity(ctx.colors[style.flat]);
        if (isFill) {
            tvgAddSvgAttribute(ctx.elem, "fill", col.color);
            tvgAddSvgAttribute(ctx.elem, "fill-opacity", col.opacity);
        } else {
            tvgAddSvgAttribute(ctx.elem, "stroke", col.color);
            tvgAddSvgAttribute(ctx.elem, "stroke-opacity", col.opacity);
        }
    } else if (style.kind === 1 || style.kind === 2) { // linear
        const grad = tvgCreateSvgGradient(ctx, style);
        if (isFill) {
            tvgAddSvgAttribute(ctx.elem, "fill", `url(#${grad})`);
        } else {
            tvgAddSvgAttribute(ctx.elem, "stroke", `url(#${grad})`);
        }
    } else throw new Error("TinyVG: attempt to apply invalid style");
}
const tvgParseFillRectangles = (ctx, size, fill_style) => {
    let count = size;
    if (count === 0) throw new Error("TinyVG: Invalid zero length filled rectangles entry");
    let rect = tvgParseRect(ctx);
    let r = tvgCreateSvgNode("rect", rect);
    ctx.doc.appendChild(r);
    ctx.elem = r;
    tvgAddSvgAttribute(ctx.elem, "fill-rule", "evenodd");
    tvgApplyStyle(ctx, fill_style, true);
    const attrs = {};
    attrs.fillRule = "evenodd";
    if (fill_style.kind !== 0) {
        attrs.fill = r.getAttributeNS(null, "fill")
    } else {
        attrs.fill = r.getAttributeNS(null, "fill")
        attrs.fillOpacity = r.getAttributeNS(null, "fill-opacity");
    }
    --count;
    while (count--) {
        rect = tvgParseRect(ctx);
        const localAttrs = { ...attrs, ...rect };
        r = tvgCreateSvgNode("rect", localAttrs);
        ctx.doc.appendChild(r);
        ctx.elem = r;
    }
}
const tvgParseLineFillRectangles = (ctx, size, fill_style, line_style, line_width) => {
    let count = size;
    if (count === 0) throw new Error("TinyVG: Invalid zero length line filled rectangles entry");
    if (line_width === 0) {  // 0 width is invalid
        line_width = .001;
    }
    let rect = tvgParseRect(ctx);
    let r = tvgCreateSvgNode("rect", rect);
    ctx.doc.appendChild(r);
    ctx.elem = r;
    tvgAddSvgAttribute(ctx.elem, "fill-rule", "evenodd");
    tvgAddSvgAttribute(ctx.elem, "stroke-width", line_width);
    tvgApplyStyle(ctx, fill_style, true);
    tvgApplyStyle(ctx, line_style, false);
    const attrs = {};
    attrs.fillRule = "evenodd";
    if (fill_style.kind !== 0) {
        attrs.fill = r.getAttributeNS(null, "fill");
    } else {
        attrs.fill = r.getAttributeNS(null, "fill");
        attrs.fillOpacity = r.getAttributeNS(null, "fill-opacity");
    }
    if (line_style.kind !== 0) {
        attrs.stroke = r.getAttributeNS(null, "stroke");
    } else {
        attrs.stroke = r.getAttributeNS(null, "stroke");
        attrs.strokeOpacity = r.getAttributeNS(null, "stroke-opacity");
    }
    attrs.strokeWidth = line_width;
    --count;
    while (count--) {
        rect = tvgParseRect(ctx);
        const localAttrs = { ...attrs, ...rect };
        r = tvgCreateSvgNode("rect", localAttrs);
        ctx.doc.appendChild(r);
        ctx.elem = r;
    }
}
const tvgParseFillPaths = (ctx, size, style) => {
    if (size === 0) throw new Error("TinyVG: Invalid zero filled paths entry");
    const attrs = {};
    attrs.fillRule = "evenodd";
    attrs.strokeOpacity = 0;
    attrs.strokeWidth = 0;
    const sizes = [];
    for (let i = 0; i < size; ++i) {
        sizes.push(tvgReadU32(ctx) + 1);
    }
    let p = tvgCreateSvgNode("path", attrs);
    ctx.doc.appendChild(p);
    ctx.elem = p;
    tvgApplyStyle(ctx, style, true);
    if (style.kind !== 0) {
        attrs.fill = p.getAttributeNS(null, "fill");
    } else {
        attrs.fill = p.getAttributeNS(null, "fill");
        attrs.fillOpacity = p.getAttributeNS(null, "fill-opacity");
    }
    let d = tvgParsePathD(ctx, sizes[0]);
    for (let i = 1; i < size; ++i) {
        d+= ` ${tvgParsePathD(ctx, sizes[i])}`;
    }
    tvgAddSvgAttribute(p, "d", d);
}
const tvgParseLinePaths = (ctx, size, line_style, line_width) => {
    if (size === 0) throw new Error("TinyVG: Invalid zero line paths entry");
    if (line_width === 0) {  // 0 width is invalid
        line_width = .001;
    }
    const attrs = {};
    const sizes = [];
    for (let i = 0; i < size; ++i) {
        sizes.push(tvgReadU32(ctx) + 1);
    }
    let p = tvgCreateSvgNode("path", attrs);
    ctx.doc.appendChild(p);
    ctx.elem = p;
    tvgAddSvgAttribute(ctx.elem, "fill-opacity", 0);
    tvgAddSvgAttribute(ctx.elem, "stroke-width", line_width);
    tvgApplyStyle(ctx, line_style, false);
    if (line_style.kind !== 0) {
        attrs.stroke = p.getAttributeNS(null, "stroke");
    } else {
        attrs.stroke = p.getAttributeNS(null, "stroke");
        attrs.strokeOpacity = p.getAttributeNS(null, "stroke-opacity");
    }
    attrs.strokeWidth = line_width;
    attrs.fillOpacity = 0;
    let d = tvgParsePathD(ctx, sizes[0]);
    for (let i = 1; i < size; ++i) {
        d+= ` ${tvgParsePathD(ctx, sizes[i])}`;
    }
    tvgAddSvgAttribute(p, "d", d);
}
const tvgParseLineFillPaths = (ctx, size, fill_style, line_style, line_width) => {
    if (size === 0) throw new Error("TinyVG: Invalid zero line filled paths entry");
    if (line_width === 0) {  // 0 width is invalid
        line_width = .001;
    }
    const attrs = {};
    attrs.fillRule = "evenodd";
    const sizes = [];
    for (let i = 0; i < size; ++i) {
        sizes.push(tvgReadU32(ctx) + 1);
    }
    let p = tvgCreateSvgNode("path", attrs);
    ctx.doc.appendChild(p);
    ctx.elem = p;
    tvgApplyStyle(ctx, fill_style, true);
    if (fill_style.kind !== 0) {
        attrs.fill = p.getAttributeNS(null, "fill");
    } else {
        attrs.fill = p.getAttributeNS(null, "fill");
        attrs.fillOpacity = p.getAttributeNS(null, "fill-opacity");
    }
    tvgApplyStyle(ctx, line_style, false);
    if (line_style.kind !== 0) {
        attrs.stroke = p.getAttributeNS(null, "stroke");
    } else {
        attrs.stroke = p.getAttributeNS(null, "stroke");
        attrs.strokeOpacity = p.getAttributeNS(null, "stroke-opacity");
    }
    attrs.strokeWidth = line_width;
    tvgAddSvgAttribute(p, "stroke-width", line_width);
    let d = tvgParsePathD(ctx, sizes[0]);
    for (let i = 1; i < size; ++i) {
        d+= ` ${tvgParsePathD(ctx, sizes[i])}`;
    }
    tvgAddSvgAttribute(p, "d", d);
}
const tvgParseFillPolygon = (ctx, size, fill_style) => {
    if (size === 0) throw new Error("TinyVG: Invalid zero polygon entry");
    let count = size;
    let points = "";
    let pt = tvgReadPoint(ctx);
    points += `${pt.x},${pt.y}`;
    while (--count) {
        pt = tvgReadPoint(ctx);
        points += ` ${pt.x},${pt.y}`;
    }
    const attrs = { fillRule: "evenodd", points: points };
    let p = tvgCreateSvgNode("polygon", attrs);
    ctx.doc.appendChild(p);
    ctx.elem = p;
    tvgApplyStyle(ctx, fill_style, true);
}
const tvgParsePolyline = (ctx, size, line_style, line_width, close) => {
    if (size === 0) throw new Error("TinyVG: Invalid zero polyline entry");
    if (line_width === 0) {  // 0 width is invalid
        line_width = .001;
    }
    let count = size;
    let points = "";
    let pt = tvgReadPoint(ctx);
    points += `${pt.x},${pt.y}`;
    while (--count) {
        pt = tvgReadPoint(ctx);
        points += ` ${pt.x},${pt.y}`;
    }
    const attrs = { points: points, lineWidth: line_width, fillOpacity: 0 };
    let p = tvgCreateSvgNode(close ? "polygon" : "polyline", attrs);
    ctx.doc.appendChild(p);
    ctx.elem = p;
    tvgApplyStyle(ctx, line_style, false);
}
const tvgParseLineFillPolyline = (ctx, size, fill_style, line_style, line_width, close) => {
    if (size === 0) throw new Error("TinyVG: Invalid zero line fill polyline entry");
    if (line_width === 0) {  // 0 width is invalid
        line_width = .001;
    }
    let count = size;
    let points = "";
    let pt = tvgReadPoint(ctx);
    points += `${pt.x},${pt.y}`;
    while (--count) {
        pt = tvgReadPoint(ctx);
        points += ` ${pt.x},${pt.y}`;
    }
    const attrs = { points: points, lineWidth: line_width, fillRule: "evenodd" };
    let p = tvgCreateSvgNode(close ? "polygon" : "polyline", attrs);
    ctx.doc.appendChild(p);
    ctx.elem = p;
    tvgApplyStyle(ctx, fill_style, true);
    tvgApplyStyle(ctx, line_style, false);
}
const tvgParseLines = (ctx, size, line_style, line_width) => {
    if (size === 0) throw new Error("TinyVG: Invalid zero lines entry");
    for (let i = 0; i < size; ++i) {
        const pt1 = tvgReadPoint(ctx);
        const pt2 = tvgReadPoint(ctx);
        const attrs = { x1: pt1.x, y1: pt1.y, x2: pt2.x, y2: pt2.y, strokeWidth: line_width };
        let l = tvgCreateSvgNode("line", attrs);
        ctx.doc.appendChild(l);
        ctx.elem = l;
        tvgApplyStyle(ctx, line_style, false);
    }
}
const tvgParseCommands = (ctx) => {
    let cmd = 255;
    while (cmd != 0) {
        cmd = ctx.view.getUint8(ctx.cursor++);
        switch (cmd & 0x3F) {
            case 0: // TVG_CMD_END_DOCUMENT:
                // console.log("TVG END");
                break;
            case 1: { // TVG_CMD_FILL_POLYGON: 
                // console.log("TVG FILL POLYGON");
                const data = tvgParseFillHeader(ctx, (cmd >>> 6) & 3);
                tvgParseFillPolygon(ctx, data.size, data.style);
            } break;
            case 2: { // TVG_CMD_FILL_RECTANGLES: 
                // console.log("TVG FILL RECTANGLES");
                const data = tvgParseFillHeader(ctx, (cmd >>> 6) & 3);
                tvgParseFillRectangles(ctx, data.size, data.style);
            } break;
            case 3: { // TVG_CMD_FILL_PATH: 
                // console.log("TVG FILL PATH");
                const data = tvgParseFillHeader(ctx, (cmd >>> 6) & 3);
                tvgParseFillPaths(ctx, data.size, data.style);
            } break;
            case 4: { // TVG_CMD_DRAW_LINES: 
                // console.log("TVG LINES");
                const data = tvgParseLineHeader(ctx, (cmd >>> 6) & 3);
                tvgParseLines(ctx, data.size, data.style, data.line_width);
            } break;
            case 5: { // TVG_CMD_DRAW_LINE_LOOP: 
                // console.log("TVG LINE LOOP");
                const data = tvgParseLineHeader(ctx, (cmd >>> 6) & 3);
                tvgParsePolyline(ctx, data.size, data.style, data.line_width, true);
            } break;
            case 6: { // TVG_CMD_DRAW_LINE_STRIP:
                // console.log("TVG LINE STRIP");
                const data = tvgParseLineHeader(ctx, (cmd >>> 6) & 3);
                tvgParsePolyline(ctx, data.size, data.style, data.line_width, false);
            } break;
            case 7: { // TVG_CMD_DRAW_LINE_PATH: 
                // console.log("TVG LINE PATH");
                const data = tvgParseLineHeader(ctx, (cmd >>> 6) & 3);
                tvgParseLinePaths(ctx, data.size, data.style, data.line_width);
            } break;
            case 8: { // TVG_CMD_OUTLINE_FILL_POLYGON: 
                // console.log("TVG OUTLINE FILL POLYGON");
                const data = tvgParseLineFillHeader(ctx, (cmd >>> 6) & 3);
                tvgParseLineFillPolyline(ctx, data.size, data.fill_style, data.line_style, data.line_width, true);
            } break;
            case 9: { // TVG_CMD_OUTLINE_FILL_RECTANGLES:
                // console.log("TVG OUTLINE FILL RECTANGLES");
                const data = tvgParseLineFillHeader(ctx, (cmd >>> 6) & 3);
                tvgParseLineFillRectangles(ctx, data.size, data.fill_style, data.line_style, data.line_width);
            } break;
            case 10: { // TVG_CMD_OUTLINE_FILL_PATH: 
                // console.log("TVG OUTLINE FILL PATH");
                const data = tvgParseLineFillHeader(ctx, (cmd >>> 6) & 3);
                tvgParseLineFillPaths(ctx, data.size, data.fill_style, data.line_style, data.line_width);
            } break;
            default:
                throw new Error(`TinyVG: Invalid command in document (0x${tvgToHex(cmd)})`);
        }
    }
}
// get the {width, height} of a TVG in an arraybuffer
export const tvgDimensions = (data) => {
    if (data) {
        const view = new DataView(data);
        if (view.byteLength > 5) {
            // check for TVG v 1.0 header
            if (view.getUint8(0) == 0x72 && view.getUint8(1) == 0x56 && view.getUint8(2) == 1) {
                const flags = view.getUint8(3);
                const range = (flags >>> 6) & 0x03;
                const w = tvgReadCoordBI(range, 4, data);
                const h = tvgReadCoordBI(range, 4 + tvgAdvCoord(range), data);
                const dim = {
                    width: tvgMapZeroToMax(range, w),
                    height: tvgMapZeroToMax(range, h)
                };
                return dim;
            }
        }
    }
    return undefined;
}
// Render a TVG in an arraybuffer (data) to an SVG tag indicated by the id
export default function tvgRender(id, data) {
    if (!id) throw new Error("TinyVG: Must specify the id of an SVG element");
    if (!data) throw new Error("TinyVG: Must provide an ArrayBuffer with TVG data");
    const view = new DataView(data);
    if (view.byteLength > 5) {
        if (view.getUint8(0) == 0x72 && view.getUint8(1) == 0x56 && view.getUint8(2) == 1) {
            const ctx = tvgInit(data, id);
            if (ctx.doc) {
                const flags = view.getUint8(3);
                ctx.scale = (flags & 0xF);
                ctx.color_encoding = ((flags >>> 4) & 0x3);
                ctx.coord_range = (flags >>> 6) & 0x03;
                ctx.cursor = 4;
                const w = tvgReadCoord(ctx);
                const h = tvgReadCoord(ctx);
                ctx.width = tvgMapZeroToMax(ctx, w);
                ctx.height = tvgMapZeroToMax(ctx, h);
                const colcount = tvgReadU32(ctx);
                if (!colcount || colcount === 0) throw new Error("TinyVG: invalid format - color table contains nothing");
                for (let i = 0; i < colcount; ++i) {
                    ctx.colors.push(tvgReadColor(ctx));
                }
                while (ctx.doc.firstChild) {
                    ctx.doc.removeChild(ctx.doc.lastChild);
                }
                tvgAddSvgAttribute(ctx.doc, "width", w.toString(10));
                tvgAddSvgAttribute(ctx.doc, "height", h.toString(10));
                tvgAddSvgAttribute(ctx.doc, "viewBox", `0 0 ${w} ${h}`);
                tvgParseCommands(ctx);
                return;
            }
        }
    }
    throw new Error("TinyVG: Not a valid TinyVG file");
}