use std::fs::File;
use std::io::{self, Read, Write};
use std::path::PathBuf;
use std::process;

mod tvg;

const HELP: &str = "\
svg2tvgt - an SVG to TinyVG converter.

USAGE:
  svg2tvgt [OPTIONS] <in-svg> <out-tvg>  # from file to file
  svg2tvgt [OPTIONS] -c <in-svg>         # from file to stdout
  svg2tvgt [OPTIONS] - <out-tvg>         # from stdin to file
  svg2tvgt [OPTIONS] - -c                # from stdin to stdout

OPTIONS:
  -h, --help                    Prints help information
  -V, --version                 Prints version information
  -c                            Prints the output TinyVG to the stdout

  --dpi DPI                     Sets the resolution
                                [default: 96] [possible values: 10..4000]
  --languages LANG              Sets a comma-separated list of languages that
                                will be used during the 'systemLanguage'
                                attribute resolving
                                Examples: 'en-US', 'en-US, ru-RU', 'en, ru'
                                [default: en]
  --resources-dir DIR           Sets a directory that will be used during
                                relative paths resolving.
                                Expected to be the same as the directory that
                                contains the SVG file, but can be set to any.
                                [default: input file directory
                                or none when reading from stdin]

  --font-family FAMILY          Sets the default font family that will be
                                used when no 'font-family' is present
                                [default: Times New Roman]
  --font-size SIZE              Sets the default font size that will be
                                used when no 'font-size' is present
                                [default: 12] [possible values: 1..192]

  --quiet                       Disables warnings

ARGS:
  <in-svg>                      Input file
  <out-tvg>                     Output file
";

#[derive(Debug)]
struct Args {
    dpi: u32,
    languages: Vec<String>,
    resources_dir: Option<PathBuf>,

    font_family: Option<String>,
    font_size: u32,

    quiet: bool,

    input: String,
    output: String,
}

fn collect_args() -> Result<Args, pico_args::Error> {
    let mut input = pico_args::Arguments::from_env();

    if input.contains(["-h", "--help"]) {
        print!("{}", HELP);
        std::process::exit(0);
    }

    if input.contains(["-V", "--version"]) {
        println!("{}", env!("CARGO_PKG_VERSION"));
        std::process::exit(0);
    }

    Ok(Args {
        dpi:                input.opt_value_from_fn("--dpi", parse_dpi)?.unwrap_or(96),
        languages:          input.opt_value_from_fn("--languages", parse_languages)?
                                 .unwrap_or(vec!["en".to_string()]),
        resources_dir:      input.opt_value_from_str("--resources-dir").unwrap_or_default(),

        font_family:        input.opt_value_from_str("--font-family")?,
        font_size:          input.opt_value_from_fn("--font-size", parse_font_size)?.unwrap_or(12),

        quiet:              input.contains("--quiet"),

        input:              input.free_from_str()?,
        output:             input.free_from_str()?,
    })
}

fn parse_dpi(s: &str) -> Result<u32, String> {
    let n: u32 = s.parse().map_err(|_| "invalid number")?;

    if n >= 10 && n <= 4000 {
        Ok(n)
    } else {
        Err("DPI out of bounds".to_string())
    }
}

fn parse_font_size(s: &str) -> Result<u32, String> {
    let n: u32 = s.parse().map_err(|_| "invalid number")?;

    if n > 0 && n <= 192 {
        Ok(n)
    } else {
        Err("font size out of bounds".to_string())
    }
}

fn parse_languages(s: &str) -> Result<Vec<String>, String> {
    let mut langs = Vec::new();
    for lang in s.split(',') {
        langs.push(lang.trim().to_string());
    }

    if langs.is_empty() {
        return Err("languages list cannot be empty".to_string());
    }

    Ok(langs)
}

#[derive(Clone, PartialEq, Debug)]
enum InputFrom<'a> {
    Stdin,
    File(&'a str),
}

#[derive(Clone, PartialEq, Debug)]
enum OutputTo<'a> {
    Stdout,
    File(&'a str),
}


fn main() {
    let args = match collect_args() {
        Ok(v) => v,
        Err(e) => {
            eprintln!("Error: {}.", e);
            process::exit(1);
        }
    };

    if !args.quiet {
        if let Ok(()) = log::set_logger(&LOGGER) {
            log::set_max_level(log::LevelFilter::Warn);
        }
    }

    if let Err(e) = process(args) {
        eprintln!("Error: {}.", e.to_string());
        std::process::exit(1);
    }
}

fn process(args: Args) -> Result<(), String> {
    let (in_svg, out_tvg) = {
        let in_svg = args.input.as_str();
        let out_svg = args.output.as_str();

        let svg_from = if in_svg == "-" {
            InputFrom::Stdin
        } else if in_svg == "-c" {
            return Err(format!("-c should be set after input"));
        } else {
            InputFrom::File(in_svg)
        };

        let svg_to = if out_svg == "-c" {
            OutputTo::Stdout
        } else {
            OutputTo::File(out_svg)
        };

        (svg_from, svg_to)
    };

    let mut fontdb = usvg::fontdb::Database::new();
    fontdb.load_system_fonts();

    let resources_dir = match args.resources_dir {
        Some(v) => Some(v),
        None => {
            match in_svg {
                InputFrom::Stdin => None,
                InputFrom::File(ref f) => {
                    // Get input file absolute directory.
                    std::fs::canonicalize(f).ok().and_then(|p| p.parent().map(|p| p.to_path_buf()))
                }
            }
        }
    };

    let re_opt = usvg::Options {
        resources_dir,
        dpi: args.dpi as f64,
        font_family: args.font_family.unwrap_or("Times New Roman".to_owned()),
        font_size: args.font_size as f64,
        languages: args.languages,
        fontdb,
        ..usvg::Options::default()
    };

    let input_svg = match in_svg {
        InputFrom::Stdin => load_stdin(),
        InputFrom::File(ref path) => std::fs::read(path).map_err(|e| e.to_string()),
    }?;

    let tree = usvg::Tree::from_data(&input_svg, &re_opt.to_ref()).map_err(|e| format!("{}", e))?;

    let doc = tvg::usvg_to_tvg(&tree);
    let tvg_text = doc.to_tvgt();
    match out_tvg {
        OutputTo::Stdout => {
            io::stdout()
                .write_all(tvg_text.as_bytes())
                .map_err(|_| format!("failed to write to the stdout"))?;
        }
        OutputTo::File(path) => {
            let mut f = File::create(path)
                .map_err(|_| format!("failed to create the output file"))?;
            f.write_all(tvg_text.as_bytes())
                .map_err(|_| format!("failed to write to the output file"))?;
        }
    }

    Ok(())
}

fn load_stdin() -> Result<Vec<u8>, String> {
    let mut buf = Vec::new();
    let stdin = io::stdin();
    let mut handle = stdin.lock();

    handle
        .read_to_end(&mut buf)
        .map_err(|_| format!("failed to read from stdin"))?;

    Ok(buf)
}

/// A simple stderr logger.
static LOGGER: SimpleLogger = SimpleLogger;
struct SimpleLogger;
impl log::Log for SimpleLogger {
    fn enabled(&self, metadata: &log::Metadata) -> bool {
        metadata.level() <= log::LevelFilter::Warn
    }

    fn log(&self, record: &log::Record) {
        if self.enabled(record.metadata()) {
            let target = if record.target().len() > 0 {
                record.target()
            } else {
                record.module_path().unwrap_or_default()
            };

            let line = record.line().unwrap_or(0);

            match record.level() {
                log::Level::Error => eprintln!("Error (in {}:{}): {}", target, line, record.args()),
                log::Level::Warn  => eprintln!("Warning (in {}:{}): {}", target, line, record.args()),
                log::Level::Info  => eprintln!("Info (in {}:{}): {}", target, line, record.args()),
                log::Level::Debug => eprintln!("Debug (in {}:{}): {}", target, line, record.args()),
                log::Level::Trace => eprintln!("Trace (in {}:{}): {}", target, line, record.args()),
            }
        }
    }

    fn flush(&self) {}
}
