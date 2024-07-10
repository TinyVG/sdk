using System;
using System.Xml;
using System.Collections.Specialized;
using System.Collections.Generic;
using System.Xml.Serialization;
using System.IO;
using System.Text;
using System.Drawing;
using System.Diagnostics;
using System.Linq;
using System.Globalization;

class Application
{
  static bool strict_mode = false;
  static bool verbose_mode = false;

  public static void ReportError(string msg)
  {
    Console.Error.WriteLine(msg);
    if (strict_mode)
      Environment.Exit(1);
  }

  public static void ReportError(string msg, params object[] args) => ReportError(string.Format(msg, args));

  public static void Report(string msg)
  {
    if (!verbose_mode)
      return;
    Console.Error.WriteLine(msg);
  }

  public static void Report(string msg, params object[] args) => ReportError(string.Format(msg, args));

  static void PrintUsage(TextWriter writer)
  {
    writer.WriteLine("svg2tvgt [--output <file>] [--strict] [--help] [--verbose] <input>");
    writer.WriteLine("");
    writer.WriteLine("Converts SVG files into TinyVG text representation. Use tvg-text to convert output into binary.");
    writer.WriteLine("");
    writer.WriteLine("Options");
    writer.WriteLine("  <input>               The SVG file to convert.");
    writer.WriteLine("  -h, --help            Prints this text");
    writer.WriteLine("  -s, --strict          Exit code will signal a failure if the file is not fully supported");
    writer.WriteLine("  -v, --verbose         Prints some logging information that might show errors in the conversion process");
    writer.WriteLine("  -o, --output <file>   Writes the output tvgt to <file>. If not given, the output will be <input> with .tvgt extension");
  }

  static int Main(string[] args)
  {
    CultureInfo.CurrentCulture = CultureInfo.InvariantCulture;
    try
    {

      string out_file_name = null;
      string input_file_name = null;

      var positionals = new List<string>();

      for (int i = 0; i < args.Length; i++)
      {
        var arg = args[i];

        if (arg == "-o" || arg == "--output")
        {
          out_file_name = args[i + 1];
          i += 1;
        }
        else if (arg == "-h" || arg == "--help")
        {
          PrintUsage(Console.Out);
          return 0;
        }
        else if (arg == "-s" || arg == "--strict")
        {
          strict_mode = true;
        }
        else if (arg == "-v" || arg == "--verbose")
        {
          strict_mode = true;
        }
        else if (arg.StartsWith("-") && arg != "-")
        {
          Console.Error.WriteLine("Unknown command line arg: {0}", arg);
          PrintUsage(Console.Error);
          return 1;
        }
        else
        {
          positionals.Add(arg);
        }
      }

      switch (positionals.Count)
      {
        case 0:
          PrintUsage(Console.Error);
          return 1;
        case 1:
          break;
        default:
          Console.Error.WriteLine("svg2tvgt requires exactly one positional argument");
          PrintUsage(Console.Error);
          return 1;
      }
      input_file_name = positionals[0];

      if (out_file_name != "-")
      {
        out_file_name = out_file_name ?? Path.ChangeExtension(input_file_name, "tvgt");
      }

      SvgDocument doc;
      if (input_file_name == "-")
      {
        doc = SvgConverter.ParseDocument(Console.In);
      }
      else
      {
        try
        {
          using (var stream = File.OpenRead(input_file_name))
          {
            doc = SvgConverter.ParseDocument(stream);
          }
        }
        catch (System.IO.FileNotFoundException)
        {
          Console.Error.WriteLine("Could not open '{0}'", input_file_name);
          return 1;
        }
      }

      var text_tvg = SvgConverter.ConvertToTvgText(doc);
      if (out_file_name == "-")
      {
        Console.Write(text_tvg);
      }
      else
      {
        using (var stream = File.Open(out_file_name, FileMode.Create, FileAccess.Write))
        {
          using (var sw = new StreamWriter(stream, new UTF8Encoding(false)))
          {
            sw.Write(text_tvg);
          }
        }
      }

    }
    catch (Exception ex)
    {
      Console.Error.WriteLine("Unhandled exception:");
      Console.Error.WriteLine(ex.ToString());
      return 1;
    }

    return 0;
  }
}

// class DevRunner
// {
//   static int Main(string[] args)
//   {
//     var render_png = false;
//     var render_tga = true;
//     var render_txt = true;

//     var banned_files = new HashSet<string>
//     {
//       // Banned for: using exponent floats.
//       // "distributor-logo-midnightbsd.svg",
//       // "twitter.svg",
//       // "cadence.svg",
//     };

//     int count = 0;
//     int unsupported_count = 0;
//     int crash_count = 0;

//     int total_svg_size = 0;
//     int total_tvg_size = 0;
//     int total_png_size = 0;

//     try
//     {
//       var src_root = "/home/felix/projects/forks/";
//       var dst_root = "/tmp/converted/";
//       foreach (var folder in new string[] {
//         src_root + "/zig-logo",
//         // src_root + "/w3c-svg-files",
//         src_root + "/MaterialDesign/svg",
//         src_root + "/papirus-icon-theme/Papirus/48x48/actions",
//         // src_root + "/papirus-icon-theme/Papirus/48x48/apps",
//         // src_root + "/papirus-icon-theme/Papirus/48x48/devices",
//         // src_root + "/papirus-icon-theme/Papirus/48x48/emblems",
//         // src_root + "/papirus-icon-theme/Papirus/48x48/emotes",
//         // src_root + "/papirus-icon-theme/Papirus/48x48/mimetypes",
//         // src_root + "/papirus-icon-theme/Papirus/48x48/places",
//         // src_root + "/papirus-icon-theme/Papirus/48x48/status",
//        })
//       {
//         foreach (var file in Directory.GetFiles(folder, "*.svg"))
//         {
//           if (banned_files.Contains(Path.GetFileName(file)))
//             continue;
//           try
//           {
//             var dst_file = dst_root + Path.GetFileName(Path.GetDirectoryName(file)) + "/" + Path.GetFileNameWithoutExtension(file) + ".tvg";

//             Console.WriteLine("parse {0} => {1}", Path.GetFileName(file), dst_file);
//             SvgDocument doc;
//             int svg_size;
//             try
//             {
//               using (var stream = File.OpenRead(file))
//               {
//                 doc = SvgConverter.ParseDocument(stream);
//                 svg_size = (int)stream.Position;
//               }
//             }
//             catch (Exception exception)
//             {
//               Console.WriteLine("Failed to parse {0}", file);
//               Process.Start("timg", file).WaitForExit();
//               var pad = "";
//               var e = exception;
//               while (e != null)
//               {
//                 Console.Error.WriteLine("{0}{1}", pad, e.Message);
//                 pad = pad + " ";
//                 e = e.InnerException;
//               }
//               return 1;
//             }
//             count += 1;

//             if (!doc.IsFullySupported)
//             {
//               unsupported_count += 1;
//               continue;
//             }

//             byte[] tvg_data;
//             try
//             {
//               tvg_data = SvgConverter.ConvertToTvg(doc);
//             }
//             catch (UnitRangeException exception)
//             {
//               Console.WriteLine("Failed to parse {0}", file);
//               var pad = "";
//               Exception e = exception;
//               while (e != null)
//               {
//                 Console.Error.WriteLine("{0}{1}", pad, e.Message);
//                 pad = pad + " ";
//                 e = e.InnerException;
//               }
//               continue;
//             }

//             Directory.CreateDirectory(Path.GetDirectoryName(dst_file));
//             File.WriteAllBytes(dst_file, tvg_data);

//             if (render_png) Process.Start("convert", file + " " + Path.ChangeExtension(dst_file, ".original.png")).WaitForExit();

//             if (render_tga)
//             {
//               Process.Start("zig-out/bin/tvg-render", dst_file).WaitForExit();
//               Process.Start("convert", Path.ChangeExtension(dst_file, ".tga") + " " + Path.ChangeExtension(dst_file, ".render.png")).WaitForExit();
//             }
//             if (render_txt)
//             {
//               Process.Start("zig-out/bin/tvg-text", dst_file).WaitForExit();
//             }

//             int tvg_size = tvg_data.Length;
//             int png_size = render_png ? File.ReadAllBytes(Path.ChangeExtension(dst_file, ".original.png")).Length : 0;

//             Console.WriteLine("SVG: {0}\t(100%)\tTVG: {1}\t({2}%),\tPNG: {3}\t(%{4})",
//               svg_size,
//               tvg_size,
//               (100 * tvg_size / svg_size),
//               png_size,
//               (100 * png_size / svg_size)
//             );
//             total_svg_size += svg_size;
//             total_tvg_size += tvg_size;
//             total_png_size += png_size;
//           }
//           catch (Exception ex)
//           {
//             Console.WriteLine("Failed to translate {0}", file);
//             if (!(ex is NotSupportedException))
//             {
//               Process.Start("timg", file).WaitForExit();
//               Console.WriteLine(ex);
//               return 1;
//               // crash_count += 1;
//             }
//           }
//         }
//       }
//     }
//     finally
//     {
//       Console.WriteLine("{0} icons parsed successfully, of which {1} are not fully supported and of which {2} crashed.", count, unsupported_count, crash_count);

//       if (SvgConverter.unknown_styles.Count > 0)
//       {
//         Console.WriteLine("Found unknown style keys:");
//         foreach (var kvp in SvgConverter.unknown_styles)
//         {
//           Console.Write("\t{0} =>", kvp.Key);
//           foreach (var value in kvp.Value)
//           {
//             Console.Write(" '{0}'", value);
//           }
//           Console.WriteLine();
//         }
//       }
//       if (total_svg_size > 0)
//       {
//         Console.WriteLine("SVG: {0}\t(100%)\tTVG: {1}\t({2}%),\tPNG: {3}\t(%{4})",
//           total_svg_size,
//           total_tvg_size,
//           (100 * total_tvg_size / total_svg_size),
//           total_png_size,
//           (100 * total_png_size / total_svg_size)
//         );
//       }
//     }
//     return 0;
//   }

// }

public static class SvgConverter
{
  static readonly XmlSerializer serializer = new XmlSerializer(typeof(SvgDocument));

  public static SvgDocument ParseDocument(Stream stream)
  {
    using (var sr = new StreamReader(stream, Encoding.UTF8))
    {
      return ParseDocument(sr);
    }
  }

  public static SvgDocument ParseDocument(TextReader text_reader)
  {
    var ignored_attribs = new HashSet<string>
    {
      "sodipodi:version",
    };

    var unsupported_attribs = new HashSet<string>{
      "class", // no support for SVG classes
      "font-weight",
      "letter-spacing",
      "word-spacing",
      "vector-effect",
      "display",
      "preserveAspectRatio",
      "filter",
      "font-size",
      "font-family",
      "font-stretch",
      "text-anchor",
      "baseProfile",
      "enable-background",
      "image-rendering",
    };

    var ignored_elements = new HashSet<string>
    {
      "metadata",
    };

    var unsupported_elements = new HashSet<string>{
      "defs", // no support for predefined styles
      "use",
      "symbol",
      "linearGradient",
      "radialGradient",
    };

    var fully_supported = true;

    var events = new XmlDeserializationEvents();
    events.OnUnknownElement = new XmlElementEventHandler((object sender, XmlElementEventArgs e) =>
    {
      if (e.Element.Prefix == "inkscape")
        return;
      if (e.Element.Prefix == "sodipodi")
        return;
      if (ignored_elements.Contains(e.Element.Name))
      {
        return;
      }
      if (unsupported_elements.Contains(e.Element.Name))
      {
        Application.ReportError("Unsupported element {0}", e.Element.Name);
        fully_supported = false;
        return;
      }
      Application.ReportError("Unknown element {0}", e.Element.Name);
      // throw new InvalidOperationException(string.Format("Unknown element {0}", e.Element.Name));
    });
    events.OnUnknownAttribute = new XmlAttributeEventHandler((object sender, XmlAttributeEventArgs e) =>
    {
      if (e.Attr.Prefix == "xml")
        return;
      if (e.Attr.Prefix == "inkscape")
        return;
      if (e.Attr.Prefix == "sodipodi")
        return;
      if (e.Attr.Name.StartsWith("aria-"))
      {
        // Ignore accessibility
        return;
      }
      if (ignored_attribs.Contains(e.Attr.Name))
      {
        return;
      }
      if (unsupported_attribs.Contains(e.Attr.Name))
      {
        fully_supported = false;
        return;
      }
      // throw new InvalidOperationException(string.Format("Unknown attribute {0}", e.Attr.Name));
      Application.ReportError("Unknown attribute {0}", e.Attr.Name);
    });
    using (var reader = XmlReader.Create(text_reader, new XmlReaderSettings
    {
      DtdProcessing = DtdProcessing.Ignore,
    }))
    {
      var doc = (SvgDocument)serializer.Deserialize(reader, events);
      doc.IsFullySupported = fully_supported;
      return doc;
    }
  }

  public static string ConvertToTvgText(SvgDocument document)
  {
    var intermediate_buffer = new AnalyzeIntermediateBuffer();

    AnalyzeNode(intermediate_buffer, document);

    var result = intermediate_buffer.Finalize(document);

    // document.TvgFillStyle = new TvgFlatColor
    // {
    //   Color = Color.Magenta,
    // };

    // this loop will only execute when a coordinate won't fit the target range.
    // The next lower scale is then selected and it's retried.
    while (true)
    {
      try
      {
        var sb = new StringBuilder();
        var stream = new TvgStream(sb, result);

        stream.WriteLine("(tvg 1");

        // Console.WriteLine("Use scale factor {0} for size limit {1}", 1 << scale_bits, coordinate_limit);

        stream.WriteLine("  ({0} {1} 1/{2} {3} {4})",
          result.image_width,
          result.image_height,
          1 << result.scale_bits,
          "u8888",
          "default"
        );

        stream.WriteLine("  (");

        // color table
        foreach (var col in result.color_table)
        {
          if (col.A != 1.0)
          {
            stream.WriteLine("    ({0} {1} {2} {3})", col.R, col.G, col.B, col.A);
          }
          else
          {
            stream.WriteLine("    ({0} {1} {2})", col.R, col.G, col.B);
          }
        }

        stream.WriteLine("  )");
        stream.WriteLine("  (");

        // Console.WriteLine("Found {0} colors in {1} nodes!", result.color_table.Length, intermediate_buffer.node_count);

        var pos_pre = sb.Length;
        {
          // var stream = new TvgStream { stream = ms, ar = result };
          TranslateNodes(result, stream, document);
        }
        if (pos_pre == sb.Length)
        {
          // throw new NotSupportedException("This SVG does not contain any supported elements!");
        }

        stream.WriteLine("  )");

        stream.WriteLine(")");

        return sb.ToString();
      }
      catch (UnitRangeException ex)
      {
        if (result.scale_bits == 0)
          throw;
        Application.Report("Reducing bit range trying to fit {0}", ex.Value);
        result.scale_bits -= 1;
      }
    }
  }

  public static float ToFloat(string s)
  {
    return float.Parse(s, CultureInfo.InvariantCulture);
  }

  public static void WriteCommandHeader(TvgStream stream, SvgNode node, TvgCommand[] cmds)
  {
    if (node.TvgFillStyle != null && node.TvgLineStyle != null)
    {
      stream.WriteCommand(cmds[2]);
    }
    else if (node.TvgFillStyle != null)
    {
      stream.WriteCommand(cmds[0]);
    }
    else
    {
      stream.WriteCommand(cmds[1]);
    }
    if (node.TvgFillStyle != null)
    {
      stream.Write(" ");
      stream.WriteStyle(node.TvgFillStyle);
    }
    if (node.TvgLineStyle != null)
    {
      stream.Write(" ");
      stream.WriteStyle(node.TvgLineStyle);
      stream.Write(" ");
      stream.WriteUnit(node.StrokeWidth);
    }
  }

  static void TranslateNodes(AnalyzeResult data, TvgStream stream, SvgNode node)
  {
    if (!string.IsNullOrWhiteSpace(node.Transform))
    {
      Application.ReportError("Node has unsupported transform: {0}", node.Transform);
    }
    if (node is SvgGroup group)
    {
      foreach (var child in group.Nodes ?? new SvgNode[0])
      {
        TranslateNodes(data, stream, child);
      }
      return;
    }
    if (node.TvgFillStyle == null && node.TvgLineStyle == null)
      return;

    if (node is SvgPolygon polygon)
    {
      var points = polygon.Points
        .Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries)
        .Select(s => s.Split(','))
        .Select(a => new PointF(ToFloat(a[0]), ToFloat(a[1])))
        .ToArray();

      stream.Write("(");

      WriteCommandHeader(stream, node, new[] { TvgCommand.fill_polygon, TvgCommand.draw_line_loop, TvgCommand.outline_fill_polygon });

      stream.Write("(\n");
      foreach (var pt in points)
      {
        stream.Write("(");
        stream.WritePoint(pt);
        stream.Write(")\n");
      }
      stream.Write(")");
    }
    else if (node is SvgPath path)
    {
      var renderer = new TvgPathRenderer(stream, node);
      // SvgPathParser.Parse(path.Data, new SvgDebugRenderer());
      SvgPathParser.Parse(path.Data, renderer);
      renderer.Finish();
    }
    else if (node is SvgRectangle rect)
    {
      if (rect.RadiusX != 0 || rect.RadiusY != 0)
      {
        if (rect.Width >= 2 * rect.RadiusX && rect.Height >= 2 * rect.RadiusY)
        {
          var dx = rect.Width - 2 * rect.RadiusX;
          var dy = rect.Height - 2 * rect.RadiusY;

          var rx = rect.RadiusX;
          var ry = rect.RadiusY;
          var rx5 = 0.5f * rx;
          var ry5 = 0.5f * ry;

          var renderer = new TvgPathRenderer(stream, node);
          // SvgPathParser.Parse(path.Data, new SvgDebugRenderer());
          SvgPathParser.Parse($"M {rect.X + rx} {rect.Y} h {dx} c {rx5} 0 {rx} 0 {rx} {ry} v {dy} c 0 {ry} -{rx} {ry} -{rx} {ry} h -{dx} c -{rx5} 0 -{rx} 0 -{rx} -{ry} v -{dy} c 0 -{ry} {rx5} -{ry} {rx} -{ry}", renderer);
          renderer.Finish();
          return;
        }

        Application.ReportError("Found invalid rounded rectangles: width=\"{0}\" height=\"{1}\" rx=\"{2}\" ry=\"{3}\"",
          rect.Width,
          rect.Height,
          rect.RadiusX,
          rect.RadiusY
        );
      }

      if (node.TvgFillStyle == null && node.TvgLineStyle != null)
      {
        // pure line drawing
      }
      else
      {
        stream.Write("(");
        WriteCommandHeader(stream, node, new[] { TvgCommand.fill_rectangles, TvgCommand.end_of_document, TvgCommand.outline_fill_rectangles });
        stream.Write(" ");
        stream.Write("((");
        stream.WriteCoordX(rect.X);
        stream.Write(" ");
        stream.WriteCoordY(rect.Y);
        stream.Write(" ");
        stream.WriteSizeX(rect.Width);
        stream.Write(" ");
        stream.WriteSizeY(rect.Height);
        stream.Write("))");
      }
    }
    else if (node is SvgCircle circle)
    {
      var x = circle.X;
      var y = circle.Y;
      var r = Math.Abs(circle.Radius);

      stream.Write("(");
      WriteCommandHeader(stream, node, new[] { TvgCommand.fill_path, TvgCommand.draw_line_path, TvgCommand.outline_fill_path });
      stream.Write(" (");
      stream.Write("({0} {1}) (", x, y - r);
      stream.Write("(arc_circle - {0} false false ({1} {2}))", r, x, y + r);
      stream.Write("(arc_circle - {0} false false ({1} {2}))", r, x, y - r);
      stream.Write(")))");
    }
    // else if (node is SvgEllipse ellipse)
    // {
    //   var x = ellipse.X;
    //   var y = ellipse.Y;
    //   var rx = Math.Abs(ellipse.RadiusX);
    //   var ry = Math.Abs(ellipse.RadiusY);

    //   stream.Write("(");
    //   WriteCommandHeader(stream, node, new[] { TvgCommand.fill_path, TvgCommand.draw_line_path, TvgCommand.outline_fill_path });
    //   stream.Write(" (");
    //   stream.Write("({0} {1}) (", x, y - r);
    //   stream.Write("(arc_ellipse - {0} {1} 0.0 false false ({2} {3}))", rx, ry, x, y + ry);
    //   stream.Write("(arc_ellipse - {0} {1} 0.0 false false ({2} {3}))", rx, ry, x, y - ry);
    //   stream.Write(")))");
    // }
    else
    {
      Application.ReportError("Not implemented: {0}", node.GetType().Name);
    }
  }

  class TvgPathRenderer : IPathRenderer
  {
    TvgStream out_stream;

    TvgStream temp_stream;
    SvgNode node;

    List<int> segments = new List<int>();

    int CurrentSegmentPrimitives
    {
      get => segments[segments.Count - 1];
      set => segments[segments.Count - 1] = value;
    }

    public TvgPathRenderer(TvgStream target, SvgNode node)
    {
      this.out_stream = target ?? throw new ArgumentNullException();
      this.temp_stream = new TvgStream(new StringBuilder(), target.ar);
      this.node = node ?? throw new ArgumentNullException();
    }

    public void Finish()
    {
      var filled_segments = segments.Where(l => l > 0).ToArray();
      if (filled_segments.Length > 0)
      {
        out_stream.Write("    (");

        SvgConverter.WriteCommandHeader(
          out_stream,
          node,
          new[] {
            TvgCommand.fill_path, TvgCommand.draw_line_path, TvgCommand.outline_fill_path
          });

        out_stream.WriteLine();
        out_stream.WriteLine("      (");
        out_stream.Write(this.temp_stream.ToString());
        out_stream.WriteLine("        )");
        out_stream.WriteLine("      )");
        out_stream.WriteLine("    )");
      }
    }

    public void MoveTo(PointF pt)
    {
      //  Console.WriteLine("MoveTo({0},{1})", pt.X, pt.Y);
      if (segments.Count > 0)
      {
        temp_stream.WriteLine("        )");
      }
      segments.Add(0);
      temp_stream.Write("        (");
      temp_stream.WritePoint(pt);
      temp_stream.WriteLine(")");
      temp_stream.WriteLine("        (");
    }

    public void LineTo(PointF pt)
    {
      // Console.WriteLine("LineTo({0},{1})", pt.X, pt.Y);
      CurrentSegmentPrimitives += 1;
      temp_stream.Write("          (line - ");
      temp_stream.WritePoint(pt);
      temp_stream.WriteLine(")");
    }

    public void VerticalTo(float y)
    {
      // Console.WriteLine("VerticalTo({0})", y);
      CurrentSegmentPrimitives += 1;
      temp_stream.Write("          (vert - ");
      temp_stream.WriteCoordY(y);
      temp_stream.WriteLine(")");
    }

    public void HorizontalTo(float x)
    {
      // Console.WriteLine("HorizontalTo({0})", x);
      CurrentSegmentPrimitives += 1;
      temp_stream.Write("          (horiz - ");
      temp_stream.WriteCoordX(x);
      temp_stream.WriteLine(")");
    }

    public void QuadCurveTo(PointF pt1, PointF pt2)
    {
      // Console.WriteLine("QuadCurveTo({0},{1},{2},{3})", pt1.X, pt1.Y, pt2.X, pt2.Y);
      CurrentSegmentPrimitives += 1;
      temp_stream.Write("          (quadratic_bezier - (");
      temp_stream.WritePoint(pt1);
      temp_stream.Write(") (");
      temp_stream.WritePoint(pt2);
      temp_stream.WriteLine("))");
    }

    public void CurveTo(PointF pt1, PointF pt2, PointF pt3)
    {
      // Console.WriteLine("CurveTo({0},{1},{2})", pt1, pt2, pt3);
      CurrentSegmentPrimitives += 1;
      temp_stream.Write("          (bezier - (");
      temp_stream.WritePoint(pt1);
      temp_stream.Write(") (");
      temp_stream.WritePoint(pt2);
      temp_stream.Write(") (");
      temp_stream.WritePoint(pt3);
      temp_stream.WriteLine("))");
    }

    public void ArcTo(PointF size, float angle, bool isLarge, bool sweep, PointF ep)
    {
      // Console.WriteLine("ArcTo()");
      if (size.X == 0 || size.Y == 0)
      {
        LineTo(ep);
        return;
      }
      CurrentSegmentPrimitives += 1;
      temp_stream.Write("          (arc_ellipse - ");
      temp_stream.WriteUnit(Math.Abs(size.X));
      temp_stream.Write(" ");
      temp_stream.WriteUnit(Math.Abs(size.Y));
      temp_stream.Write(" ");
      temp_stream.WriteUnit(angle);
      temp_stream.Write(" ");
      temp_stream.WriteBoolean(isLarge);
      temp_stream.Write(" ");
      temp_stream.WriteBoolean(!sweep); // SVG sweep is inverse to TVG sweep
      temp_stream.Write(" (");
      temp_stream.WritePoint(ep);
      temp_stream.WriteLine("))");
    }

    public void ClosePath()
    {
      CurrentSegmentPrimitives += 1;
      // Console.WriteLine("ClosePath()");
      temp_stream.WriteLine("          (close -)");
    }
  }

  static Color? AnalyzeStyleDef(AnalyzeIntermediateBuffer buf, string fill, float opacity)
  {
    if (fill == "none")
      return null;
    return buf.InsertColor(fill, opacity);
  }
  public static Dictionary<string, HashSet<string>> unknown_styles = new Dictionary<string, HashSet<string>>();

  static void AnalyzeNode(AnalyzeIntermediateBuffer buf, SvgNode node, string indent = "")
  {
    buf.node_count += 1;

    var style = new NameValueCollection();
    if (node.Style != null)
    {
      foreach (var kvp in node.Style.Split(new[] { ';' }, StringSplitOptions.RemoveEmptyEntries).Select(s => s.Split(':')).ToDictionary(
       a => a[0].Trim().ToLower(),
       a => a[1].Trim()
     ))
      {
        style[kvp.Key] = kvp.Value;
      }
    }

    if (node.Fill != null)
      style["fill"] = node.Fill;
    if (node.Stroke != null)
      style["stroke"] = node.Stroke;
    if (node.Opacity != 1)
      style["opacity"] = node.Opacity.ToString();

    float opacity = ToFloat(style["opacity"] ?? "1");

    foreach (string key in style.AllKeys)
    {
      switch (key)
      {
        case "fill":
        case "opacity":
        case "stroke":
        case "fill-opacity":
        case "stroke-opacity":
        case "color":
          break;
        default:
          if (!unknown_styles.TryGetValue(key, out var set))
            unknown_styles.Add(key, set = new HashSet<string>());
          set.Add(style[key]);
          break;
      }
    }

    var no_fill = false;
    // var no_stroke = false;

    var fill = style["fill"];
    if (fill != null)
    {
      float fill_opacity = opacity * node.FillOpacity * ToFloat(style["fill-opacity"] ?? "1");
      var color = AnalyzeStyleDef(buf, fill, fill_opacity);
      if (color != null)
      {
        node.TvgFillStyle = new TvgFlatColor { Color = color.Value };
      }
      else
      {
        no_fill = true;
      }
    }

    var stroke = style["stroke"] ?? style["color"];
    if (stroke != null)
    {
      float stroke_opacity = opacity * ToFloat(style["stroke-opacity"] ?? "1");
      var color = AnalyzeStyleDef(buf, stroke, stroke_opacity);
      if (color != null)
      {
        node.TvgLineStyle = new TvgFlatColor { Color = color.Value };
      }
      else
      {
        // no_stroke = true;
      }
    }

    if (node is SvgGroup group)
    {
      foreach (var child in group.Nodes ?? new SvgNode[0])
      {
        child.Parent = node;
        AnalyzeNode(buf, child, indent + " ");
      }
    }
    else
    {
      if (!no_fill && node.TvgFillStyle == null)
      {
        node.TvgFillStyle = new TvgFlatColor { Color = buf.InsertColor("#000", opacity) };
      }
    }

    // Console.WriteLine(
    //   "{5}Analyzed {0} with {1} ({2}) and {3} ({4})",
    //   node.GetType().Name,
    //   node.TvgFillStyle?.ToString() ?? "<null>", fill ?? "<null>",
    //   node.TvgLineStyle?.ToString() ?? "<null>", stroke ?? "<null>",
    //   indent);
  }


  public static void Assert(bool b)
  {
    if (!b) throw new InvalidOperationException("Assertion failed!");
  }
}

public enum TvgCommand : byte
{
  end_of_document = 0,

  fill_polygon = 1,
  fill_rectangles = 2,
  fill_path = 3,

  draw_lines = 4,
  draw_line_loop = 5,
  draw_line_strip = 6,
  draw_line_path = 7,

  outline_fill_polygon = 8,
  outline_fill_rectangles = 9,
  outline_fill_path = 10,

};

public struct Color
{
  public float R, G, B, A;

  public static Color Placeholder = new Color { R = 1.0f, G = 0.0f, B = 1.0f, A = 1.0f };
  public static Color Transparent = new Color { R = 1.0f, G = 0.0f, B = 1.0f, A = 0.0f };

  public Color(float gray) : this(gray, gray, gray) { }

  public Color(float r, float g, float b) : this(r, g, b, 1.0f) { }

  public Color(float r, float g, float b, float a)
  {
    this.R = r;
    this.G = g;
    this.B = b;
    this.A = a;
  }

  public static Color FromArgb(int a, int r, int g, int b)
  {
    return new Color(r / 255.0f, g / 255.0f, b / 255.0f, a / 255.0f);
  }

  public static Color FromArgb(int r, int g, int b)
  {
    return new Color(r / 255.0f, g / 255.0f, b / 255.0f);
  }

  public override int GetHashCode()
  {
    return base.GetHashCode();
  }

  static bool ApproxEq(float a, float b)
  {
    return Math.Abs(a - b) < (1.0 / 4096.0); // 12 bit color depth
  }

  public bool Equals(Color c)
  {
    return ApproxEq(R, c.R) && ApproxEq(G, c.G) && ApproxEq(B, c.B) && ApproxEq(A, c.A);
  }

  public override bool Equals(object obj)
  {
    if (obj is Color c)
    {
      return Equals(c);
    }
    else
    {
      return false;
    }
  }

  public override string ToString()
  {
    return string.Format("{0:0.00} {1:0.00} {2:0.00} {3:0.00}", R, G, B, A);
  }
}

public class AnalyzeIntermediateBuffer
{
  List<Color> colors = new List<Color>();

  public int node_count = 0;

  private static byte ScaleColorValue(int val, int digits)
  {
    switch (digits)
    {
      case 0: throw new NotSupportedException();
      case 1: return (byte)(val | (val << 4));
      case 2: return (byte)val;
      default: return (byte)((double)val * (256 / Math.Pow(16, digits)));
    }
  }

  private static Color TranslateColor(string text)
  {
    var named_color = WebColors.Get(text);
    if (named_color != null)
      return named_color.Value;

    switch (text)
    {
      case "#value_dark": return new Color(0.0f);
      case "#value_middle": return new Color(0.5f);
      case "#value_light": return new Color(1.0f);
    }

    if (text.StartsWith("#") && text.Length > 1)
    {
      int components_rgb = (text.Length - 1) / 3;
      int components_rgba = (text.Length - 1) / 4;

      bool is_rgb = (3 * components_rgb + 1 == text.Length);
      bool is_rgba = (4 * components_rgba + 1 == text.Length);
      SvgConverter.Assert(is_rgb == false || is_rgba == false); // must both be false

      if (is_rgb)
      {
        string text_r = text.Substring(1 + 0 * components_rgb, components_rgb);
        string text_g = text.Substring(1 + 1 * components_rgb, components_rgb);
        string text_b = text.Substring(1 + 2 * components_rgb, components_rgb);

        int r = ScaleColorValue(Convert.ToInt32(text_r, 16), components_rgb);
        int g = ScaleColorValue(Convert.ToInt32(text_g, 16), components_rgb);
        int b = ScaleColorValue(Convert.ToInt32(text_b, 16), components_rgb);
        return Color.FromArgb(r, g, b);
      }
      else if (is_rgb)
      {
        string text_r = text.Substring(1 + 0 * components_rgb, components_rgb);
        string text_g = text.Substring(1 + 1 * components_rgb, components_rgb);
        string text_b = text.Substring(1 + 2 * components_rgb, components_rgb);
        string text_a = text.Substring(1 + 3 * components_rgb, components_rgb);

        int r = ScaleColorValue(Convert.ToInt32(text_r, 16), components_rgb);
        int g = ScaleColorValue(Convert.ToInt32(text_g, 16), components_rgb);
        int b = ScaleColorValue(Convert.ToInt32(text_b, 16), components_rgb);
        int a = ScaleColorValue(Convert.ToInt32(text_a, 16), components_rgb);
        return Color.FromArgb(a, r, g, b);
      }
    }

    // var html_color = ColorTranslator.FromHtml(text);
    // if (html_color == Color.Empty)

    Application.ReportError("Failed to translate color spec '{0}'", text);
    return Color.Placeholder;
  }

  private static Color TranslateColor(string text, float opacity)
  {
    var color = TranslateColor(text);
    color.A *= opacity;
    return color;
  }

  public Color InsertColor(string text, float opacity)
  {
    var color = TranslateColor(text, opacity);
    // Console.Error.WriteLine("insertColor({0}, {1}) => {2}", text, opacity, color);
    if (!this.colors.Contains(color))
    {
      this.colors.Add(color);
    }
    return color;
  }

  int ParseSvgSize(string src)
  {
    if (string.IsNullOrWhiteSpace(src))
      return 0;
    if (src.ToLower() == "auto")
      return 0;
    src = new string(src.TakeWhile(c => char.IsDigit(c) || (c == '.')).ToArray());
    return (int)(SvgConverter.ToFloat(src) + 0.5f);
  }

  public AnalyzeResult Finalize(SvgDocument doc)
  {
    int width = ParseSvgSize(doc.Width);
    int height = ParseSvgSize(doc.Height);

    float[] viewport = doc.ViewBox?.Split(' ').Select(SvgConverter.ToFloat).ToArray() ?? new float[] {
      0, 0, width, height,
    };

    SvgConverter.Assert(viewport.Length == 4);

    if (width == 0 && height == 0)
    {
      width = (int)(viewport[2] + 0.5);
      height = (int)(viewport[3] + 0.5);
    }
    else if (width == 0)
    {
      height = width;
    }
    else if (height == 0)
    {
      height = width;
    }

    // determine the maximum precision for the given image size
    int coordinate_limit = Math.Max(width, height);
    int scale_bits = 0;
    while (scale_bits < 15 && (coordinate_limit << (scale_bits + 1)) < 32768)
    {
      scale_bits += 1;
    }
    SvgConverter.Assert(scale_bits < 16);


    if (colors.Count == 0)
    {
      colors.Add(Color.FromArgb(0, 0, 0));
    }

    // Console.Error.WriteLine("viewbox = {0} {1} {2} {3}", viewport[0], viewport[1], viewport[2], viewport[3]);
    // Console.Error.WriteLine("size    = {0} {1}", width, height);

    return new AnalyzeResult
    {
      scale_bits = scale_bits,
      color_table = colors.ToArray(),
      image_width = width,
      image_height = height,
      viewport_x = viewport[0],
      viewport_y = viewport[1],
      viewport_width = viewport[2],
      viewport_height = viewport[3],
    };
  }
}

public class AnalyzeResult
{
  public int scale_bits;
  public Color[] color_table;

  public int image_width;
  public int image_height;

  public float viewport_x;
  public float viewport_y;
  public float viewport_width;
  public float viewport_height;

  public float viewport_scale_x;
  public float viewport_scale_y;

  public ushort GetColorIndex(Color color)
  {
    for (ushort i = 0; i < color_table.Length; i++)
    {
      if (color_table[i].Equals(color))
        return i;
    }
    throw new ArgumentOutOfRangeException("color", $"color {color} was not previously registered!");
  }
}

[XmlRoot("svg", Namespace = "http://www.w3.org/2000/svg")]
public class SvgDocument : SvgGroup
{
  [XmlAttribute("version")]
  public string Version { get; set; }

  [XmlAttribute("viewBox")]
  public string ViewBox { get; set; }

  [XmlAttribute("x")]
  public float X { get; set; }

  [XmlAttribute("y")]
  public float Y { get; set; }

  [XmlAttribute("width")]
  public string Width { get; set; }

  [XmlAttribute("height")]
  public string Height { get; set; }


  public bool IsFullySupported { get; set; }
}

// style="opacity:0.5;fill:#ffffff"
// overflow="visible"
// stroke="#fff" stroke-linecap="round" stroke-linejoin="round" stroke-width="4"
public class SvgNode
{
  [XmlAttribute("id")]
  public string ID { get; set; }

  [XmlAttribute("style")]
  public string Style { get; set; }

  [XmlAttribute("transform")]
  public string Transform { get; set; }

  [XmlAttribute("fill")]
  public string Fill { get; set; }

  [XmlAttribute("opacity")]
  public float Opacity { get; set; } = 1.0f;

  [XmlAttribute("fill-opacity")]
  public float FillOpacity { get; set; } = 1.0f;

  [XmlAttribute("overflow")]
  public string Overflow { get; set; }

  [XmlAttribute("stroke")]
  public string Stroke { get; set; }

  [XmlAttribute("stroke-width")]
  public float StrokeWidth { get; set; } = 1.0f;

  [XmlAttribute("stroke-miterlimit")]
  public float StrokeMiterLimit { get; set; }

  [XmlAttribute("stroke-linecap")]
  public string StrokeLineCap { get; set; }

  [XmlAttribute("stroke-linejoin")]
  public string StrokeLineJoin { get; set; }

  [XmlAttribute("clip-path")]
  public string ClipPath { get; set; }

  [XmlAttribute("shape-rendering")]
  public string ShapeRendering { get; set; }

  [XmlAttribute("fill-rule")]
  public string FillRule { get; set; }

  [XmlAttribute("clip-rule")]
  public string ClipRule { get; set; }

  // TVG Implementation starts here

  public SvgNode Parent { get; set; }

  TvgStyle local_fill_style = null;
  public TvgStyle TvgFillStyle
  {
    get { return local_fill_style ?? Parent?.TvgFillStyle; }
    set { local_fill_style = value; }
  }

  TvgStyle local_line_style = null;
  public TvgStyle TvgLineStyle
  {
    get { return local_line_style ?? Parent?.TvgLineStyle; }
    set { local_line_style = value; }
  }
}

public enum Overflow
{
  [XmlEnum("visible")] Visible,
}

public class SvgGroup : SvgNode
{
  [XmlElement("path", typeof(SvgPath))]
  [XmlElement("text", typeof(SvgText))]
  [XmlElement("rect", typeof(SvgRectangle))]
  [XmlElement("circle", typeof(SvgCircle))]
  [XmlElement("ellipse", typeof(SvgEllipse))]
  [XmlElement("style", typeof(SvgStyle))]
  [XmlElement("polygon", typeof(SvgPolygon))]
  [XmlElement("polyline", typeof(SvgPolyline))]
  [XmlElement("g", typeof(SvgGroup))]
  [XmlElement("a", typeof(SvgLink))]
  public SvgNode[] Nodes { get; set; }
}


public class SvgLink : SvgGroup
{

}

// fill="#fff" opacity=".2"
// d="M 21 21 L 21 29 L 25 29 L 25 25 L 29 25 L 29 21 L 25 21 L 21 21 z M 31 21 L 31 25 L 35 25 L 35 29 L 39 29 L 39 21 L 35 21 L 31 21 z M 21 31 L 21 39 L 25 39 L 29 39 L 29 35 L 25 35 L 25 31 L 21 31 z M 35 31 L 35 35 L 31 35 L 31 39 L 35 39 L 39 39 L 39 31 L 35 31 z"
// fill-rule="evenodd"
public class SvgPath : SvgNode
{
  [XmlAttribute("d")]
  public string Data { get; set; }
}


public class SvgText : SvgNode
{
  [XmlAttribute("x")]
  public float X { get; set; }

  [XmlAttribute("y")]
  public float Y { get; set; }

  [XmlAttribute("font-size")]
  public string FontSize { get; set; }

  [XmlAttribute("font-family")]
  public string FontFamily { get; set; }

  [XmlText]
  public string Data { get; set; }
}


// width="28" height="28" x="16" y="16" rx="2.211" ry="2.211" transform="matrix(0,1,1,0,0,0)"
public class SvgRectangle : SvgNode
{
  [XmlAttribute("x")]
  public float X { get; set; }

  [XmlAttribute("y")]
  public float Y { get; set; }

  [XmlAttribute("width")]
  public float Width { get; set; }

  [XmlAttribute("height")]
  public float Height { get; set; }

  [XmlAttribute("rx")]
  public float RadiusX { get; set; }

  [XmlAttribute("ry")]
  public float RadiusY { get; set; }
}

// cx="12" cy="24" r="4"
public class SvgCircle : SvgNode
{
  [XmlAttribute("cx")]
  public float X { get; set; }

  [XmlAttribute("cy")]
  public float Y { get; set; }

  [XmlAttribute("r")]
  public float Radius { get; set; }
}
// cx="-10.418" cy="28.824" rx="4.856" ry="8.454" transform="matrix(0.70812504,-0.70608705,0.51863379,0.85499649,0,0)"
public class SvgEllipse : SvgNode
{
  [XmlAttribute("cx")]
  public float X { get; set; }

  [XmlAttribute("cy")]
  public float Y { get; set; }

  [XmlAttribute("r")]
  public float Radius { get { throw new NotSupportedException(); } set { RadiusX = value; RadiusY = value; } }

  [XmlAttribute("rx")]
  public float RadiusX { get; set; }

  [XmlAttribute("ry")]
  public float RadiusY { get; set; }
}

public class SvgStyle : SvgNode
{
  [XmlAttribute("type")]
  public string MimeType { get; set; }

  [XmlText]
  public string Content { get; set; }
}

public class SvgPolygon : SvgNode
{
  [XmlAttribute("points")]
  public string Points { get; set; }
}

public class SvgPolyline : SvgNode
{
  [XmlAttribute("points")]
  public string Points { get; set; }
}

public class TvgStream : StringWriter
{

  public readonly AnalyzeResult ar;

  public TvgStream(StringBuilder sb, AnalyzeResult ar) :
    base(sb, CultureInfo.InvariantCulture)
  {
    this.ar = ar ?? throw new ArgumentNullException(nameof(ar));
  }


  public void WriteBoolean(bool b)
  {
    Write("{0}", b ? "true" : "false");
  }

  public void WriteUnit(float value)
  {
    int scale = (1 << ar.scale_bits);
    try
    {
      checked
      {
        int unit = (int)(value * scale + 0.5);
        if (unit < short.MinValue || unit > short.MaxValue)
          throw new UnitRangeException(value, unit, scale);
        Write("{0}", value);
      }
    }
    catch (OverflowException)
    {
      throw new UnitRangeException(value, scale);
    }
  }

  public void WriteSizeX(float x)
  {
    WriteUnit(x * (ar.image_width / ar.viewport_width));
  }

  public void WriteCoordX(float x)
  {
    WriteSizeX(x - ar.viewport_x);
  }

  public void WriteSizeY(float y)
  {
    WriteUnit(y * (ar.image_height / ar.viewport_height));
  }

  public void WriteCoordY(float y)
  {
    WriteSizeY(y - ar.viewport_y);
  }

  public void WritePoint(float x, float y)
  {
    WriteCoordX(x);
    Write(" ");
    WriteCoordY(y);
  }

  public void WritePoint(PointF f) => WritePoint(f.X, f.Y);

  public void WriteColorIndex(Color c)
  {
    WriteUnsignedInt(ar.GetColorIndex(c));
  }

  public void WriteUnsignedInt(uint val)
  {
    Write("{0}", val);
    // if (val == 0)
    // {
    //   stream.WriteByte(0);
    //   return;
    // }
    // while (val != 0)
    // {
    //   byte mask = 0x00;
    //   if (val > 0x7F)
    //     mask = 0x80;
    //   stream.WriteByte((byte)((val & 0x7F) | mask));
    //   val >>= 7;
    // }
  }

  public void WriteCommand(TvgCommand cmd) => Write(cmd.ToString());

  // public void WriteCountAndStyleType(int count, TvgStyle style)
  // {
  //   if (count > 64)
  //     throw new NotSupportedException($"Cannot encode {count} elements!");
  //   if (count == 0) throw new ArgumentOutOfRangeException("Cannot encode 0 path elements!");
  //   WriteByte((byte)((style.GetStyleType() << 6) | ((count == 64) ? 0 : count)));
  // }

  public void WriteStyle(TvgStyle style) => style.WriteData(ar, this);

  // public void Write(byte[] buffer)
  // {
  //   stream.Write(buffer);
  // }
}

public abstract class TvgStyle
{
  public abstract byte GetStyleType();
  public abstract void WriteData(AnalyzeResult ar, TvgStream stream);
}

public class TvgFlatColor : TvgStyle
{
  public Color Color;

  public override byte GetStyleType() => 0;

  public override void WriteData(AnalyzeResult ar, TvgStream stream)
  {
    stream.Write("(flat {0})", ar.GetColorIndex(Color));
  }

  public override string ToString() => Color.ToString();
}

public abstract class TvgGradient : TvgStyle
{
  public PointF StartPosition;
  public PointF EndPosition;

  public Color StartColor;
  public Color EndColor;

  public override void WriteData(AnalyzeResult ar, TvgStream stream)
  {
    stream.Write("((");
    stream.WritePoint(StartPosition);
    stream.Write(") (");
    stream.WritePoint(EndPosition);
    stream.Write(")");
    stream.WriteUnsignedInt(ar.GetColorIndex(StartColor));
    stream.Write(" ");
    stream.WriteUnsignedInt(ar.GetColorIndex(EndColor));
    stream.Write(")");
  }
}

public class TvgLinearGradient : TvgGradient
{
  public override byte GetStyleType() => 1;
  public override string ToString() => "[Linear Gradient]";
}

public class TvgRadialGradient : TvgGradient
{
  public override byte GetStyleType() => 2;
  public override string ToString() => "[Radial Gradient]";
}

public interface IPathRenderer
{
  void MoveTo(PointF pt);
  void LineTo(PointF pt);
  void VerticalTo(float y);
  void HorizontalTo(float x);
  void QuadCurveTo(PointF pt1, PointF pt2);
  void CurveTo(PointF pt1, PointF pt2, PointF pt3);
  void ArcTo(PointF size, float angle, bool isLarge, bool sweep, PointF ep);
  void ClosePath();
}

// Free after
// https://www.w3.org/TR/SVG2/paths.html#PathDataBNF
public class SvgPathParser
{
  public static void Parse(string str, IPathRenderer renderer)
  {
    var parser = new SvgPathParser(str, renderer);
    try
    {
      parser.ParsePath();
    }
    catch
    {
      parser.PrintContext("Error Context");
      throw;
    }
  }

  readonly string path_text;
  readonly IPathRenderer renderer;

  int char_offset = 0;

  PointF current_position = new PointF(0, 0);
  PointF? path_start = null;
  PointF? stored_control_point = null;

  private SvgPathParser(string str, IPathRenderer renderer)
  {
    this.path_text = str;
    this.renderer = renderer;
  }


  bool EndOfString => (char_offset >= path_text.Length);

  void PrintContext(string prefix)
  {
    var len = path_text.Length - char_offset;
    var rest = (len > 40) ? path_text.Substring(char_offset, 40) + "…" : path_text.Substring(char_offset);
    Application.Report("{0}: '{1}\u0332{2}'", prefix, path_text.Substring(0, char_offset), rest);
  }

  char? PeekChar()
  {
    if (EndOfString)
      return null;
    return path_text[char_offset];
  }

  char GetChar()
  {
    if (EndOfString)
      throw new EndOfStreamException("No more characters!");
    var c = path_text[char_offset];
    char_offset += 1;
    return c;
  }

  struct ParserState
  {
    public SvgPathParser self;
    public int offset;
    public void Restore()
    {
      self.char_offset = offset;
    }
    public string Slice()
    {
      return self.path_text.Substring(offset, self.char_offset - offset);
    }
  }

  ParserState Save()
  {
    return new ParserState { self = this, offset = char_offset };
  }

  char AcceptChar(string list) => AcceptChar(list.ToCharArray());

  char AcceptChar(params char[] list)
  {
    var c = GetChar();
    if (!list.Contains(c))
      throw new Exception("Unexpected char '" + c + "', expected one of " + string.Join(", ", list));
    return c;
  }

  char? PeekAny(string list) => PeekAny(list.ToCharArray());

  char? PeekAny(params char[] list)
  {
    var c = PeekChar();
    if (c == null)
      return null;
    if (list.Contains(c.Value))
      return c;
    return null;
  }

  static PointF Add(PointF a, PointF b) => new PointF(a.X + b.X, a.Y + b.Y);

  PointF MoveCursor(float dx, float dy, bool relative) => MoveCursor(new PointF(dx, dy), relative);
  float MoveCursorX(float dx, bool relative) => MoveCursor(new PointF(dx, relative ? 0.0f : current_position.Y), relative).X;
  float MoveCursorY(float dy, bool relative) => MoveCursor(new PointF(relative ? 0.0f : current_position.X, dy), relative).Y;

  PointF MoveCursor(PointF pt, bool relative)
  {
    current_position = MakeAbsolute(pt, relative);
    return current_position;
  }

  PointF MakeAbsolute(PointF pt, bool relative)
  {
    if (relative)
      return Add(current_position, pt);
    else
      return pt;
  }

  void SetLastControlPoint(PointF cp1)
  {
    // Mirrors the current 
    this.stored_control_point = Add(
      current_position,
      new PointF(current_position.X - cp1.X, current_position.Y - cp1.Y)
    );
    // Console.Error.WriteLine("=> SCP = {0}", this.stored_control_point);
  }

  void ResetLastControlPoint()
  {
    // Console.Error.WriteLine("~~ SCP = {0}", this.stored_control_point);
    this.stored_control_point = null;
  }

  PointF LastControlPoint => this.stored_control_point ?? this.current_position;

  // svg_path::= wsp* moveto? (moveto drawto_command*)?
  void ParsePath()
  {
    SkipWhitespace();

    ParseMoveTo();

    while (!EndOfString)
    {
      SkipWhitespace();
      if (EndOfString)
        break;
      ParseDrawToCommand();
    }
  }

  // drawto_command::=
  //     moveto
  //     | closepath
  //     | lineto
  //     | horizontal_lineto
  //     | vertical_lineto
  //     | curveto
  //     | smooth_curveto
  //     | quadratic_bezier_curveto
  //     | smooth_quadratic_bezier_curveto
  //     | elliptical_arc
  void ParseDrawToCommand()
  {
    var c = PeekChar();
    if (c == null) throw new InvalidOperationException();
    switch (c.Value)
    {
      case 'Z':
      case 'z':
        ResetLastControlPoint();
        ParseClosePath();
        break;
      case 'M':
      case 'm':
        ResetLastControlPoint();
        ParseMoveTo();
        break;
      case 'L':
      case 'l':
        ResetLastControlPoint();
        ParseLineTo();
        break;
      case 'H':
      case 'h':
        ResetLastControlPoint();
        ParseHorizontalLineTo();
        break;
      case 'V':
      case 'v':
        ResetLastControlPoint();
        ParseVerticalLineTo();
        break;
      case 'C':
      case 'c':
        ParseCurveTo();
        break;
      case 'S':
      case 's':
        ParseSmoothCurveTo();
        break;
      case 'Q':
      case 'q':
        ParseQuadraticBezierTo();
        break;
      case 'T':
      case 't':
        ParseSmoothQuadraticBezierTo();
        break;
      case 'A':
      case 'a':
        ResetLastControlPoint();
        ParseArcTo();
        break;

      default:
        throw new ArgumentException("Unexpected character: " + c.Value);
    }
  }

  // closepath::=
  //     ("Z" | "z")
  void ParseClosePath()
  {
    AcceptChar('Z', 'z');
    if (path_start == null) throw new InvalidOperationException("ClosePath detected without MoveTo");
    current_position = (PointF)path_start;
    path_start = null;
    renderer.ClosePath();
    SkipWhitespace();
  }

  // moveto::=
  //     ( "M" | "m" ) wsp* coordinate_pair_sequence
  void ParseMoveTo()
  {
    bool relative = (AcceptChar('M', 'm') == 'm');
    SkipWhitespace();
    var first = true;
    foreach (var pair in ParseCoordinatePairSequence())
    {
      var p = MoveCursor(pair, relative);
      if (first)
      {
        if (path_start != null) throw new InvalidOperationException("New MoveTo detected without ClosePath");
        path_start = current_position;
        renderer.MoveTo(p);
      }
      else
      {
        renderer.LineTo(p);
      }
      first = false;
    }
  }

  // lineto::=
  //     ("L"|"l") wsp* coordinate_pair_sequence
  void ParseLineTo()
  {
    var relative = (AcceptChar('L', 'l') == 'l');
    SkipWhitespace();
    foreach (var pair in ParseCoordinatePairSequence())
    {
      renderer.LineTo(MoveCursor(pair, relative));
    }
  }

  // horizontal_lineto::=
  //     ("H"|"h") wsp* coordinate_sequence
  void ParseHorizontalLineTo()
  {
    var relative = (AcceptChar('H', 'h') == 'h');
    SkipWhitespace();
    foreach (var x in ParseCoordinateSequence())
    {
      renderer.HorizontalTo(MoveCursorX(x, relative));
    }
  }

  // vertical_lineto::=
  //     ("V"|"v") wsp* coordinate_sequence
  void ParseVerticalLineTo()
  {
    var relative = (AcceptChar('V', 'v') == 'v');
    SkipWhitespace();
    foreach (var y in ParseCoordinateSequence())
    {
      renderer.VerticalTo(MoveCursorY(y, relative));
    }
  }

  // curveto::=
  //     ("C"|"c") wsp* curveto_coordinate_sequence

  // curveto_coordinate_sequence::=
  //     coordinate_pair_triplet
  //     | (coordinate_pair_triplet comma_wsp? curveto_coordinate_sequence)

  void ParseCurveTo()
  {
    var relative = (AcceptChar('C', 'c') == 'c');
    SkipWhitespace();
    foreach (var tup in ParseCoordinatePairTupleSequence(3))
    {
      var cp0 = MakeAbsolute(tup[0], relative);
      var cp1 = MakeAbsolute(tup[1], relative);
      var dest = MoveCursor(tup[2], relative);
      renderer.CurveTo(cp0, cp1, dest);
      SetLastControlPoint(cp1);
    }
  }

  // smooth_curveto::=
  //     ("S"|"s") wsp* smooth_curveto_coordinate_sequence

  // smooth_curveto_coordinate_sequence::=
  //     coordinate_pair_double
  //     | (coordinate_pair_double comma_wsp? smooth_curveto_coordinate_sequence)

  void ParseSmoothCurveTo()
  {
    var relative = (AcceptChar('S', 's') == 's');
    SkipWhitespace();
    foreach (var tup in ParseCoordinatePairTupleSequence(2))
    {
      var cp0 = LastControlPoint;
      var cp1 = MakeAbsolute(tup[0], relative);
      var dest = MoveCursor(tup[1], relative);
      renderer.CurveTo(cp0, cp1, dest);
      SetLastControlPoint(cp1);
    }
  }

  // quadratic_bezier_curveto::=
  //     ("Q"|"q") wsp* quadratic_bezier_curveto_coordinate_sequence

  // quadratic_bezier_curveto_coordinate_sequence::=
  //     coordinate_pair_double
  //     | (coordinate_pair_double comma_wsp? quadratic_bezier_curveto_coordinate_sequence)

  void ParseQuadraticBezierTo()
  {
    var relative = (AcceptChar('Q', 'q') == 'q');
    SkipWhitespace();
    foreach (var tup in ParseCoordinatePairTupleSequence(2))
    {
      var cp = MakeAbsolute(tup[0], relative);
      var dest = MoveCursor(tup[1], relative);
      renderer.QuadCurveTo(cp, dest);
      SetLastControlPoint(cp);
    }
  }

  // smooth_quadratic_bezier_curveto::=
  //     ("T"|"t") wsp* coordinate_pair_sequence
  void ParseSmoothQuadraticBezierTo()
  {
    var relative = (AcceptChar('T', 't') == 't');
    SkipWhitespace();
    foreach (var dest_loc in ParseCoordinatePairSequence())
    {
      var cp = LastControlPoint;
      var dest = MoveCursor(dest_loc, relative);
      renderer.QuadCurveTo(cp, dest);
      SetLastControlPoint(cp);
    }
  }

  struct EllipseArg
  {
    public float radius_x;
    public float radius_y;
    public float angle;
    public bool large_arc;
    public bool sweep;
    public PointF target;
  }

  // elliptical_arc::=
  //     ( "A" | "a" ) wsp* elliptical_arc_argument_sequence

  void ParseArcTo()
  {
    var relative = (AcceptChar('A', 'a') == 'a');
    SkipWhitespace();
    foreach (var args in ParseEllipseArgSequence())
    {
      renderer.ArcTo(
        new PointF(args.radius_x, args.radius_y),
        args.angle,
        args.large_arc,
        args.sweep,
        MoveCursor(args.target, relative)
      );
    }
  }

  // elliptical_arc_argument_sequence::=
  //     elliptical_arc_argument
  //     | (elliptical_arc_argument comma_wsp? elliptical_arc_argument_sequence)

  IEnumerable<EllipseArg> ParseEllipseArgSequence()
  {
    yield return ParseEllipseArgument();
    while (true)
    {
      var loc = Save();
      EllipseArg p;
      try
      {
        SkipCommaWhitespace();
        p = ParseEllipseArgument();
      }
      catch
      {
        loc.Restore();
        yield break;
      }
      yield return p;
    }
  }


  // elliptical_arc_argument::=
  //     number comma_wsp? number comma_wsp? number comma_wsp
  //     flag comma_wsp? flag comma_wsp? coordinate_pair
  EllipseArg ParseEllipseArgument()
  {
    var loc = Save();

    try
    {
      var result = new EllipseArg();
      result.radius_x = ParseCoordinate();
      SkipCommaWhitespace();
      result.radius_y = ParseCoordinate();
      SkipCommaWhitespace();
      result.angle = ParseCoordinate();
      SkipCommaWhitespace(false);
      result.large_arc = ParseFlag();
      SkipCommaWhitespace();
      result.sweep = ParseFlag();
      SkipCommaWhitespace();
      result.target = ParseCoordinatePair();
      return result;
    }
    catch
    {
      loc.Restore();
      throw;
    }
  }

  // coordinate_pair_double::=
  //     coordinate_pair comma_wsp? coordinate_pair
  // coordinate_pair_triplet::=
  //     coordinate_pair comma_wsp? coordinate_pair comma_wsp? coordinate_pair

  IEnumerable<PointF[]> ParseCoordinatePairTupleSequence(int tuple_size)
  {
    yield return ParseCoordinatePairTuple(tuple_size);
    while (true)
    {
      var loc = Save();
      PointF[] p;
      try
      {
        SkipCommaWhitespace();
        p = ParseCoordinatePairTuple(tuple_size);
      }
      catch
      {
        loc.Restore();
        yield break;
      }
      yield return p;
    }
  }

  PointF[] ParseCoordinatePairTuple(int tuple_size)
  {
    var tuple = new PointF[tuple_size];
    var loc = Save();
    tuple[0] = ParseCoordinatePair();
    try
    {
      for (int i = 1; i < tuple_size; i++)
      {
        SkipCommaWhitespace();
        tuple[i] = ParseCoordinatePair();
      }
      return tuple;
    }
    catch
    {
      loc.Restore();
      throw;
    }
  }

  // coordinate_pair_sequence::=
  //     coordinate_pair | (coordinate_pair comma_wsp? coordinate_pair_sequence)
  IEnumerable<PointF> ParseCoordinatePairSequence()
  {
    yield return ParseCoordinatePair();
    while (true)
    {
      var loc = Save();
      PointF p;
      try
      {
        SkipWhitespace();
        p = ParseCoordinatePair();
      }
      catch
      {
        loc.Restore();
        yield break;
      }
      yield return p;
    }
  }

  // coordinate_sequence::=
  //     coordinate | (coordinate comma_wsp? coordinate_sequence)
  IEnumerable<float> ParseCoordinateSequence()
  {
    yield return ParseCoordinate();
    while (true)
    {
      var loc = Save();
      float v;
      try
      {
        SkipWhitespace();
        v = ParseCoordinate();
      }
      catch
      {
        loc.Restore();
        yield break;
      }
      yield return v;
    }
  }

  // coordinate_pair::= coordinate comma_wsp? coordinate
  PointF ParseCoordinatePair()
  {
    var loc = Save();
    try
    {
      float x = ParseCoordinate();
      SkipCommaWhitespace();
      float y = ParseCoordinate();
      return new PointF(x, y);
    }
    catch
    {
      loc.Restore();
      throw;
    }
  }

  // coordinate::= sign? number
  // sign::= "+"|"-"
  float ParseCoordinate()
  {
    return ParseNumberGeneric(true);
  }

  // number ::= ([0-9])+
  float ParseNumber()
  {
    return ParseNumberGeneric(false);
  }

  bool ScanOne(string s)
  {
    if (char_offset < path_text.Length && s.Contains(path_text[char_offset])) {
      char_offset++;
      return true;
    }
    return false;
  }

  delegate bool IncludeCallback(char c);

  void ScanWhile(IncludeCallback cb)
  {
    while (char_offset < path_text.Length) {
      if (!cb(path_text[char_offset]))
        return;
      char_offset++;
    }
  }

  float ParseNumberGeneric(bool allow_sign)
  {
    var begin = Save();

    char first = AcceptChar("0123456789." + (allow_sign ? "+-" : ""));
    ScanWhile(char.IsDigit);
    if (first != '.' && ScanOne(".")) {
        ScanWhile(char.IsDigit);
    }
    if (ScanOne("eE")) {
        ScanOne("+-");
        ScanWhile(char.IsDigit);
    }
    return ParseFloat(begin.Slice());
  }

  static float ParseFloat(string str)
  {
    try
    {
      return float.Parse(str, CultureInfo.InvariantCulture);
    }
    catch
    {
      Application.Report("Float Context: '{0}'", str);
      throw;
    }
  }

  // flag::=("0"|"1")
  bool ParseFlag()
  {
    return (AcceptChar("01") == '1');
  }

  // wsp ::= (#x9 | #x20 | #xA | #xC | #xD)
  // comma_wsp ::= (wsp+ ","? wsp*) | ("," wsp*)

  const string valid_whitespace = "\x09\x20\x0A\x0C\x0D";

  void SkipCommaWhitespace() => SkipCommaWhitespace(true);

  void SkipCommaWhitespace(bool allow_empty)
  {
    var first = true;
    while (true)
    {
      var c = PeekAny(valid_whitespace + ",");

      if (c == null)
      {
        if (!allow_empty && first)
          throw new InvalidOperationException("Expected whitespace or comma!");
        return;
      }
      first = false;
      GetChar();
      if (c.Value == ',')
        break;
    }
    SkipWhitespace();
  }

  void SkipWhitespace()
  {
    while (true)
    {
      if (PeekAny(valid_whitespace + ",") == null)
        return;
      GetChar();
    }
  }
}


class SvgDebugRenderer : IPathRenderer
{
  public void MoveTo(PointF pt)
  {
    Console.WriteLine("MoveTo({0},{1})", pt.X, pt.Y);
  }
  public void LineTo(PointF pt)
  {
    Console.WriteLine("LineTo({0},{1})", pt.X, pt.Y);
  }
  public void VerticalTo(float y)
  {
    Console.WriteLine("VerticalTo({0})", y);
  }
  public void HorizontalTo(float x)
  {
    Console.WriteLine("HorizontalTo({0})", x);
  }
  public void QuadCurveTo(PointF pt1, PointF pt2)
  {
    Console.WriteLine("QuadCurveTo({0},{1},{2},{3})", pt1.X, pt1.Y, pt2.X, pt2.Y);
  }
  public void CurveTo(PointF pt1, PointF pt2, PointF pt3)
  {
    Console.WriteLine("CurveTo({0},{1},{2},{3},{4},{5})", pt1.X, pt1.Y, pt2.X, pt2.Y, pt3.X, pt3.Y);
  }
  public void ArcTo(PointF size, float angle, bool isLarge, bool sweep, PointF ep)
  {
    Console.WriteLine("ArcTo({0},{1},{2},{3},{4},{5},{6})", size.X, size.Y, angle, isLarge, sweep, ep.X, ep.Y);
  }
  public void ClosePath()
  {
    Console.WriteLine("ClosePath()");
  }
}

[System.Serializable]
public class UnitRangeException : System.Exception
{
  public UnitRangeException(float value, int scale) :
    base(string.Format("{0} is out of range when encoded with scale {1}", value, scale))
  {
    this.Value = value;
  }

  public UnitRangeException(float value, int unit, int scale) :
    base(string.Format("{0} is out of range when encoded as {1} with scale {2}", value, unit, scale))
  {
    this.Value = value;
  }

  protected UnitRangeException(
      System.Runtime.Serialization.SerializationInfo info,
      System.Runtime.Serialization.StreamingContext context) : base(info, context) { }

  public float Value { get; }
}

static class WebColors
{
  public static Color? Get(string name)
  {
    Color res;
    if (predefined_colors.TryGetValue(name.ToLower(), out res))
      return res;
    return null;
  }

  // see https://drafts.csswg.org/css-color/#named-colors
  static readonly Dictionary<string, Color> predefined_colors = new Dictionary<string, Color> {
    { "aliceblue", Color.FromArgb(240, 248, 255) },
    { "antiquewhite", Color.FromArgb(250, 235, 215) },
    { "aqua", Color.FromArgb(0, 255, 255) },
    { "aquamarine", Color.FromArgb(127, 255, 212) },
    { "azure", Color.FromArgb(240, 255, 255) },
    { "beige", Color.FromArgb(245, 245, 220) },
    { "bisque", Color.FromArgb(255, 228, 196) },
    { "black", Color.FromArgb(0, 0, 0) },
    { "blanchedalmond", Color.FromArgb(255, 235, 205) },
    { "blue", Color.FromArgb(0, 0, 255) },
    { "blueviolet", Color.FromArgb(138, 43, 226) },
    { "brown", Color.FromArgb(165, 42, 42) },
    { "burlywood", Color.FromArgb(222, 184, 135) },
    { "cadetblue", Color.FromArgb(95, 158, 160) },
    { "chartreuse", Color.FromArgb(127, 255, 0) },
    { "chocolate", Color.FromArgb(210, 105, 30) },
    { "coral", Color.FromArgb(255, 127, 80) },
    { "cornflowerblue", Color.FromArgb(100, 149, 237) },
    { "cornsilk", Color.FromArgb(255, 248, 220) },
    { "crimson", Color.FromArgb(220, 20, 60) },
    { "cyan", Color.FromArgb(0, 255, 255) },
    { "darkblue", Color.FromArgb(0, 0, 139) },
    { "darkcyan", Color.FromArgb(0, 139, 139) },
    { "darkgoldenrod", Color.FromArgb(184, 134, 11) },
    { "darkgray", Color.FromArgb(169, 169, 169) },
    { "darkgreen", Color.FromArgb(0, 100, 0) },
    { "darkgrey", Color.FromArgb(169, 169, 169) },
    { "darkkhaki", Color.FromArgb(189, 183, 107) },
    { "darkmagenta", Color.FromArgb(139, 0, 139) },
    { "darkolivegreen", Color.FromArgb(85, 107, 47) },
    { "darkorange", Color.FromArgb(255, 140, 0) },
    { "darkorchid", Color.FromArgb(153, 50, 204) },
    { "darkred", Color.FromArgb(139, 0, 0) },
    { "darksalmon", Color.FromArgb(233, 150, 122) },
    { "darkseagreen", Color.FromArgb(143, 188, 143) },
    { "darkslateblue", Color.FromArgb(72, 61, 139) },
    { "darkslategray", Color.FromArgb(47, 79, 79) },
    { "darkslategrey", Color.FromArgb(47, 79, 79) },
    { "darkturquoise", Color.FromArgb(0, 206, 209) },
    { "darkviolet", Color.FromArgb(148, 0, 211) },
    { "deeppink", Color.FromArgb(255, 20, 147) },
    { "deepskyblue", Color.FromArgb(0, 191, 255) },
    { "dimgray", Color.FromArgb(105, 105, 105) },
    { "dimgrey", Color.FromArgb(105, 105, 105) },
    { "dodgerblue", Color.FromArgb(30, 144, 255) },
    { "firebrick", Color.FromArgb(178, 34, 34) },
    { "floralwhite", Color.FromArgb(255, 250, 240) },
    { "forestgreen", Color.FromArgb(34, 139, 34) },
    { "fuchsia", Color.FromArgb(255, 0, 255) },
    { "gainsboro", Color.FromArgb(220, 220, 220) },
    { "ghostwhite", Color.FromArgb(248, 248, 255) },
    { "gold", Color.FromArgb(255, 215, 0) },
    { "goldenrod", Color.FromArgb(218, 165, 32) },
    { "gray", Color.FromArgb(128, 128, 128) },
    { "green", Color.FromArgb(0, 128, 0) },
    { "greenyellow", Color.FromArgb(173, 255, 47) },
    { "grey", Color.FromArgb(128, 128, 128) },
    { "honeydew", Color.FromArgb(240, 255, 240) },
    { "hotpink", Color.FromArgb(255, 105, 180) },
    { "indianred", Color.FromArgb(205, 92, 92) },
    { "indigo", Color.FromArgb(75, 0, 130) },
    { "ivory", Color.FromArgb(255, 255, 240) },
    { "khaki", Color.FromArgb(240, 230, 140) },
    { "lavender", Color.FromArgb(230, 230, 250) },
    { "lavenderblush", Color.FromArgb(255, 240, 245) },
    { "lawngreen", Color.FromArgb(124, 252, 0) },
    { "lemonchiffon", Color.FromArgb(255, 250, 205) },
    { "lightblue", Color.FromArgb(173, 216, 230) },
    { "lightcoral", Color.FromArgb(240, 128, 128) },
    { "lightcyan", Color.FromArgb(224, 255, 255) },
    { "lightgoldenrodyellow", Color.FromArgb(250, 250, 210) },
    { "lightgray", Color.FromArgb(211, 211, 211) },
    { "lightgreen", Color.FromArgb(144, 238, 144) },
    { "lightgrey", Color.FromArgb(211, 211, 211) },
    { "lightpink", Color.FromArgb(255, 182, 193) },
    { "lightsalmon", Color.FromArgb(255, 160, 122) },
    { "lightseagreen", Color.FromArgb(32, 178, 170) },
    { "lightskyblue", Color.FromArgb(135, 206, 250) },
    { "lightslategray", Color.FromArgb(119, 136, 153) },
    { "lightslategrey", Color.FromArgb(119, 136, 153) },
    { "lightsteelblue", Color.FromArgb(176, 196, 222) },
    { "lightyellow", Color.FromArgb(255, 255, 224) },
    { "lime", Color.FromArgb(0, 255, 0) },
    { "limegreen", Color.FromArgb(50, 205, 50) },
    { "linen", Color.FromArgb(250, 240, 230) },
    { "magenta", Color.FromArgb(255, 0, 255) },
    { "maroon", Color.FromArgb(128, 0, 0) },
    { "mediumaquamarine", Color.FromArgb(102, 205, 170) },
    { "mediumblue", Color.FromArgb(0, 0, 205) },
    { "mediumorchid", Color.FromArgb(186, 85, 211) },
    { "mediumpurple", Color.FromArgb(147, 112, 219) },
    { "mediumseagreen", Color.FromArgb(60, 179, 113) },
    { "mediumslateblue", Color.FromArgb(123, 104, 238) },
    { "mediumspringgreen", Color.FromArgb(0, 250, 154) },
    { "mediumturquoise", Color.FromArgb(72, 209, 204) },
    { "mediumvioletred", Color.FromArgb(199, 21, 133) },
    { "midnightblue", Color.FromArgb(25, 25, 112) },
    { "mintcream", Color.FromArgb(245, 255, 250) },
    { "mistyrose", Color.FromArgb(255, 228, 225) },
    { "moccasin", Color.FromArgb(255, 228, 181) },
    { "navajowhite", Color.FromArgb(255, 222, 173) },
    { "navy", Color.FromArgb(0, 0, 128) },
    { "oldlace", Color.FromArgb(253, 245, 230) },
    { "olive", Color.FromArgb(128, 128, 0) },
    { "olivedrab", Color.FromArgb(107, 142, 35) },
    { "orange", Color.FromArgb(255, 165, 0) },
    { "orangered", Color.FromArgb(255, 69, 0) },
    { "orchid", Color.FromArgb(218, 112, 214) },
    { "palegoldenrod", Color.FromArgb(238, 232, 170) },
    { "palegreen", Color.FromArgb(152, 251, 152) },
    { "paleturquoise", Color.FromArgb(175, 238, 238) },
    { "palevioletred", Color.FromArgb(219, 112, 147) },
    { "papayawhip", Color.FromArgb(255, 239, 213) },
    { "peachpuff", Color.FromArgb(255, 218, 185) },
    { "peru", Color.FromArgb(205, 133, 63) },
    { "pink", Color.FromArgb(255, 192, 203) },
    { "plum", Color.FromArgb(221, 160, 221) },
    { "powderblue", Color.FromArgb(176, 224, 230) },
    { "purple", Color.FromArgb(128, 0, 128) },
    { "rebeccapurple", Color.FromArgb(102, 51, 153) },
    { "red", Color.FromArgb(255, 0, 0) },
    { "rosybrown", Color.FromArgb(188, 143, 143) },
    { "royalblue", Color.FromArgb(65, 105, 225) },
    { "saddlebrown", Color.FromArgb(139, 69, 19) },
    { "salmon", Color.FromArgb(250, 128, 114) },
    { "sandybrown", Color.FromArgb(244, 164, 96) },
    { "seagreen", Color.FromArgb(46, 139, 87) },
    { "seashell", Color.FromArgb(255, 245, 238) },
    { "sienna", Color.FromArgb(160, 82, 45) },
    { "silver", Color.FromArgb(192, 192, 192) },
    { "skyblue", Color.FromArgb(135, 206, 235) },
    { "slateblue", Color.FromArgb(106, 90, 205) },
    { "slategray", Color.FromArgb(112, 128, 144) },
    { "slategrey", Color.FromArgb(112, 128, 144) },
    { "snow", Color.FromArgb(255, 250, 250) },
    { "springgreen", Color.FromArgb(0, 255, 127) },
    { "steelblue", Color.FromArgb(70, 130, 180) },
    { "tan", Color.FromArgb(210, 180, 140) },
    { "teal", Color.FromArgb(0, 128, 128) },
    { "thistle", Color.FromArgb(216, 191, 216) },
    { "tomato", Color.FromArgb(255, 99, 71) },
    { "turquoise", Color.FromArgb(64, 224, 208) },
    { "violet", Color.FromArgb(238, 130, 238) },
    { "wheat", Color.FromArgb(245, 222, 179) },
    { "white", Color.FromArgb(255, 255, 255) },
    { "whitesmoke", Color.FromArgb(245, 245, 245) },
    { "yellow", Color.FromArgb(255, 255, 0) },
    { "yellowgreen", Color.FromArgb(154, 205, 5) },
  };
}
