# TinyVG Software Development Kit

This SDK enables you to work with the [TinyVG](https://tinyvg.tech/) vector graphics format.

## Contents

- Native Library (C ABI)
- Zig Package
- Command Line Tooling
  - Offline Rendering (TVG -> TGA)
  - Format Conversion (SVG <-> TVG <-> TVGT)

## Building

The SDK is implemented with [Zig](https://ziglang.org/) and [Rust](https://www.rust-lang.org/tools/install). Until Zig 1.0 this repo tracks Zig `master` branch.

To build the SDK (except `svg2tvgt`), do this:

```sh-session
[user@host sdk]$ zig build
[user@host sdk]$
```

This will then produce the folders `zig-cache` (for temporary files) and `zig-out`, which contains the SDK files for your current platform.

To build `svg2tvgt`, go into the folder `src/tools/svg2tvgt` and do this:

```sh-session
[user@host sdk]$ cd src/tools/svg2tvgt/
[user@host svg2tvgt]$ cargo build --release
```

This will then produce `src/tools/svg2tvgt/target/release/svg2tvgt` (or `.exe` if you are on windows).
