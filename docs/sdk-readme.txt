
 ███████                █     █ ▗█████▖    ▗█████▖ ██████▖ █   ▗█▘
    █    █ █▖   █ █▖ ▗█ █     █ █▘    █    █▘   ▝█ █    ▝█ █  ▗█▘ 
    █    █ ██▖  █ ▝█▄█▘ █     █ █          █▖      █     █ █ ▗█▘  
    █    █ █▝█▖ █  ▝█▘  █▖   ▗█ █  ████    ▝█████▖ █     █ ███▌   
    █    █ █ ▝█▖█   █   ▝█▖ ▗█▘ █     █         ▝█ █     █ █ ▝█▖  
    █    █ █  ▝██   █    ▝█▄█▘  █▖   ▗█    █▖   ▗█ █    ▗█ █  ▝█▖ 
    █    █ █   ▝█   █     ▝█▘   ▝█████▘    ▝█████▘ ██████▘ █   ▝█▖

Introduction:
  This is the SDK for the TinyVG vector graphics format.

Structure:
├── examples           => Contains both image and code examples
├── js                 => Contains the polyfill to use TinyVG on websites
├── native             => Contains tooling and libraries for native development
├── specification.pdf  => The format specification
└── zig                => Contains a zig package.

Tools:

  tvg-text [-I <fmt>] [-O <fmt>] [-o <output>] <input>
    Converts TinyVG related files between different formats. Only supports a single input and output file.

    Options:
      <input>                     defines the input file, performs auto detection of the format if -I is not specified. Use - for stdin.
      -h, --help                  prints this text.
      -I, --input-format  <fmt>   sets the format of the input file.
      -O, --output-format <fmt>   sets the format of the output file.
      -o, --output <file>         sets the output file, or use - for stdout. performs auto detection of the format if -O is not specified.

    Support formats:
      tvg  - Tiny vector graphics, binary representation.
      tvgt - Tiny vector graphics, text representation.
      svg  - Scalable vector graphics. Only usable for output, use svg2tvgt to convert to tvg text format.

  tvg-render [-o <file.tga>] [-g <geometry>] [-a] [-s <scale>] <input>
    Renders a TinyVG vector graphic into a TGA file. 

    Options:
      -h, --help             Prints this text.
      -o, --output <file>    The TGA file that should be written. Default is <input> with .tga extension.
      -g, --geometry         Specifies the output geometry of the image. Has the format <width>x<height>.
          --width <width>    Specifies the output width to be <width>. Height will be derived via aspect ratio.
          --height <height>  Specifies the output height to be <height>. Width will be derived via aspect ratio.
      -s, --super-sampling   Sets the super-sampling size for the image. Use 1 for no super sampling and 16 for very high quality.
      -a, --anti-alias       Sets the super-sampling size to 4. This is usually decent enough for most images.

  svg2tvgt [-o <file>] [-s] [-h] [-v] <input>
    Converts SVG files into TinyVG text representation. Use tvg-text to convert output into binary.

    Options
      <input>               The SVG file to convert.
      -h, --help            Prints this text
      -s, --strict          Exit code will signal a failure if the file is not fully supported
      -v, --verbose         Prints some logging information that might show errors in the conversion process
      -o, --output <file>   Writes the output tvgt to <file>. If not given, the output will be <input> with .tvgt extension

Cookbook:

  Convert a SVG into a TVG file:

    svg2tvgt my-file.svg
    tvg-text my-file.tvgt -o my-file.tvg

  Convert a TVGT file to a SVG:

    tvg-text my-file.tvgt -o my-file.svg
  
  Print the TVGT source of a TVG file to stdout:

    tvg-text my-file.tvg -O tvgt -o -
  
  Run the native example on linux:

    cc examples/code/usage.c -I native/include/ -L native/$(uname -m)-linux/lib -ltinyvg
    LD_LIBRARY_PATH=native/x86_64-linux/lib/ ./a.out

Known problems:
  - x86_64-windows static library does not work with VisualStudio
  - macos dynamic library requires rpath patching
  - aarch64-macos doesn't have svg2tvgt
  - dynamic linking of static library doesn't work on void-musl
  - svg2tvgt fails to parse some relative paths