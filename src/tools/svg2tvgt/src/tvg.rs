#![allow(dead_code)]

#[derive(Debug)]
pub struct Document {
    pub width: u32,
    pub height: u32,
    pub scale: u32,
    pub color_encoding: ColorEncoding,
    pub coordinate_range: CoordinateRange,
    pub colors: Vec<Color>,
    pub commands: Vec<Command>,
}

impl Document {
    fn push_color(&mut self, color: usvg::Color) -> u32 {
        let color = Color::from(color);
        if let Some(idx) = self.colors.iter().position(|c| *c == color) {
            idx as u32
        } else {
            self.colors.push(color);
            (self.colors.len() - 1) as u32
        }
    }

    pub fn to_tvgt(&self) -> String {
        let mut buf = String::new();
        let _ = self.to_tvgt_inner(&mut buf);
        buf
    }

    fn to_tvgt_inner(&self, buf: &mut String) -> Result<(), std::fmt::Error> {
        use std::fmt::Write;

        fn write_style(style: &Style, buf: &mut String) -> Result<(), std::fmt::Error> {
            match style {
                Style::Flat { color } => {
                    writeln!(buf, "      (flat {})", color)?;
                }
                Style::LinearGradient { x1, y1, x2, y2, color1, color2 } => {
                    writeln!(buf, "      (linear ({} {}) ({} {}) {} {})",
                             x1, y1, x2, y2, color1, color2)?;
                }
                Style::RadialGradient { x1, y1, x2, y2, color1, color2 } => {
                    writeln!(buf, "      (radial ({} {}) ({} {}) {} {})",
                             x1, y1, x2, y2, color1, color2)?;
                }
            }

            Ok(())
        }

        writeln!(buf, "(tvg 1")?;
        writeln!(
            buf,
            "  ({} {} {} {} {})",
            self.width,
            self.height,
            "1/1",
            "u8888",
            "default",
        )?;

        writeln!(buf, "  (")?;
        for color in &self.colors {
            writeln!(
                buf,
                "    ({:.3} {:.3} {:.3} {:.3})",
                f32::from(color.red) / 255.0,
                f32::from(color.green) / 255.0,
                f32::from(color.blue) / 255.0,
                f32::from(color.alpha) / 255.0,
            )?;
        }
        writeln!(buf, "  )")?;

        writeln!(buf, "  (")?;
        for command in &self.commands {
            writeln!(buf, "    (")?;

            let path = match command {
                Command::DrawLinePath { stroke, line_width, path } => {
                    writeln!(buf, "      draw_line_path")?;
                    write_style(stroke, buf)?;
                    writeln!(buf, "      {}", line_width)?;
                    path
                }
                Command::FillPath { fill, path } => {
                    writeln!(buf, "      fill_path")?;
                    write_style(fill, buf)?;
                    path
                }
                Command::OutlineFillPath { stroke, fill, line_width, path } => {
                    writeln!(buf, "      outline_fill_path")?;
                    write_style(fill, buf)?;
                    write_style(stroke, buf)?;
                    writeln!(buf, "      {}", line_width)?;
                    path
                }
            };

            writeln!(buf, "      (")?;
            let mut is_open: bool = false;
            for segment in path {
                match segment {
                    usvg::PathSegment::MoveTo { x, y } => {
                        if is_open {
                            writeln!(buf, "        )")?;
                        }
                        writeln!(buf, "        ({} {})", x, y)?;
                        writeln!(buf, "        (")?;
                        is_open = true;
                    }
                    usvg::PathSegment::LineTo { x, y } => {
                        writeln!(buf, "          (line - {} {})", x, y)?;
                    }
                    usvg::PathSegment::CurveTo { x1, y1, x2, y2, x, y } => {
                        writeln!(buf, "          (bezier - ({} {}) ({} {}) ({} {}))",
                                 x1, y1, x2, y2, x, y)?;
                    }
                    usvg::PathSegment::ClosePath => {
                        writeln!(buf, "          (close -)")?;
                    }
                }
            }
             if is_open {
                writeln!(buf, "        )")?;
            }
            writeln!(buf, "      )")?;
            writeln!(buf, "    )")?;
        }
        writeln!(buf, "  )")?;
        writeln!(buf, ")")?;

        Ok(())
    }
}

#[derive(Clone, Copy, Debug)]
pub enum ColorEncoding {
    Rgba8888,
    Rgb565,
    RgbaF32,
    Custom,
}

#[derive(Clone, Copy, Debug)]
pub enum CoordinateRange {
    /// Each Unit takes up 16 bit.
    Default,
    /// Each Unit takes up 8 bit.
    Reduced,
    /// Each Unit takes up 32 bit.
    Enhanced,
}

#[derive(Clone, Copy, PartialEq, Debug)]
pub struct Color {
    pub red: u8,
    pub green: u8,
    pub blue: u8,
    pub alpha: u8,
}

impl From<usvg::Color> for Color {
    fn from(c: usvg::Color) -> Self {
        Color { red: c.red, green: c.green, blue: c.blue, alpha: c.alpha }
    }
}

#[derive(Debug)]
pub enum Command {
    DrawLinePath {
        stroke: Style,
        line_width: f32,
        path: Vec<usvg::PathSegment>,
    },
    FillPath {
        fill: Style,
        path: Vec<usvg::PathSegment>,
    },
    OutlineFillPath {
        stroke: Style,
        fill: Style,
        line_width: f32,
        path: Vec<usvg::PathSegment>,
    },
}

#[derive(Debug)]
pub enum Style {
    Flat {
        color: u32
    },
    LinearGradient {
        x1: f32,
        y1: f32,
        x2: f32,
        y2: f32,
        color1: u32,
        color2: u32,
    },
    RadialGradient {
        x1: f32,
        y1: f32,
        x2: f32,
        y2: f32,
        color1: u32,
        color2: u32,
    }
}

pub fn usvg_to_tvg(tree: &usvg::Tree) -> Document {
    let svg_node = tree.svg_node();

    let mut doc = Document {
        width: svg_node.size.width().round() as u32,
        height: svg_node.size.height().round() as u32,
        scale: 1,
        color_encoding: ColorEncoding::Rgba8888,
        coordinate_range: CoordinateRange::Default,
        colors: Vec::new(),
        commands: Vec::new(),
    };

    let viewbox_ts = usvg::utils::view_box_to_transform(
        svg_node.view_box.rect,
        svg_node.view_box.aspect,
        svg_node.size
    );

    convert_children(tree, &tree.root(), viewbox_ts, &mut doc);

    doc
}

fn convert_children(
    tree: &usvg::Tree,
    parent: &usvg::Node,
    transform: usvg::Transform,
    doc: &mut Document
) {
    for child in parent.children() {
        match *child.borrow() {
            usvg::NodeKind::Group(ref g) => {
                let mut ts = transform.clone();
                ts.append(&g.transform);
                convert_children(tree, &child, ts, doc);
            }
            usvg::NodeKind::Path(ref path) => {
                let mut new_path: usvg::PathData = (*path.data).clone();
                new_path.transform(transform);

                let bbox = match new_path.bbox() {
                    Some(bbox) => bbox,
                    None => continue,
                };

                let fill = path.fill.clone()
                    .and_then(|fill| convert_paint(tree, &fill.paint, bbox, doc));
                let stroke = path.stroke.clone()
                    .and_then(|stroke| convert_paint(tree, &stroke.paint, bbox, doc));

                let cmd = match (fill, stroke) {
                    (Some(fill), Some(stroke)) => {
                        Command::OutlineFillPath {
                            stroke,
                            fill,
                            line_width: path.stroke.as_ref().unwrap().width.value() as f32,
                            path: new_path.0,
                        }
                    }
                    (Some(fill), None) => {
                        Command::FillPath {
                            fill,
                            path: new_path.0,
                        }
                    }
                    (None, Some(stroke)) => {
                        Command::DrawLinePath {
                            stroke,
                            line_width: path.stroke.as_ref().unwrap().width.value() as f32,
                            path: new_path.0,
                        }
                    }
                    (None, None) => continue,
                };

                doc.commands.push(cmd);
            }
            _ => {}
        }
    }
}

fn convert_paint(
    tree: &usvg::Tree,
    paint: &usvg::Paint,
    bbox: usvg::PathBbox,
    doc: &mut Document,
) -> Option<Style> {
    match paint {
        usvg::Paint::Color(color) => {
            Some(Style::Flat { color: doc.push_color(*color) })
        }
        usvg::Paint::Link(ref id) => {
            if let Some(node) = tree.defs_by_id(id) {
                match *node.borrow() {
                    usvg::NodeKind::LinearGradient(ref grad) => {
                        let ts = gradient_transform(grad, bbox)?;

                        let (x1, y1) = ts.apply(grad.x1, grad.y1);
                        let (x2, y2) = ts.apply(grad.x2, grad.y2);

                        let (color1, color2) = convert_gradient_colors(&grad.stops, doc);
                        Some(Style::LinearGradient {
                            x1: x1 as f32,
                            y1: y1 as f32,
                            x2: x2 as f32,
                            y2: y2 as f32,
                            color1,
                            color2
                        })
                    }
                    usvg::NodeKind::RadialGradient(ref grad) => {
                        let ts = gradient_transform(grad, bbox)?;

                        let (x1, y1) = ts.apply(grad.cx, grad.cy);
                        let (x2, y2) = ts.apply(grad.cx, grad.cy + grad.r.value());

                        let (color1, color2) = convert_gradient_colors(&grad.stops, doc);
                        Some(Style::RadialGradient {
                            x1: x1 as f32,
                            y1: y1 as f32,
                            x2: x2 as f32,
                            y2: y2 as f32,
                            color1,
                            color2
                        })
                    }
                    _ => None,
                }
            } else {
                None
            }
        }
    }
}

fn gradient_transform(g: &usvg::BaseGradient, bbox: usvg::PathBbox) -> Option<usvg::Transform> {
    if g.units == usvg::Units::ObjectBoundingBox {
        let bbox = match bbox.to_rect() {
            Some(bbox) => bbox,
            None => {
                log::warn!("Gradient on zero-sized shapes is not allowed.");
                return None;
            }
        };

        let mut ts = usvg::Transform::new(bbox.width(), 0.0, 0.0, bbox.height(), bbox.x(), bbox.y());
        ts.append(&g.transform);
        Some(ts)
    } else {
        Some(g.transform)
    }
}

fn convert_gradient_colors(stops: &[usvg::Stop], doc: &mut Document) -> (u32, u32) {
    // Unwrap is safe, because usvg guarantees to have at least two values.
    let mut stop1 = *stops.first().unwrap();
    let mut stop2 = *stops.last().unwrap();

    // NOTE: we do ignore stop offsets

    stop1.color.alpha = multiply_a8(stop1.color.alpha, stop1.opacity.to_u8());
    stop2.color.alpha = multiply_a8(stop2.color.alpha, stop2.opacity.to_u8());

    (doc.push_color(stop1.color), doc.push_color(stop2.color))
}

/// Return a*b/255, rounding any fractional bits.
fn multiply_a8(c: u8, a: u8) -> u8 {
    let prod = u32::from(c) * u32::from(a) + 128;
    ((prod + (prod >> 8)) >> 8) as u8
}
