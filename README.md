# TinyVG Software Development Kit

This SDK enables you to work with the [TinyVG](https://tinyvg.tech/) vector graphics format.

## Contents

- Native Library (C ABI)
- Zig Package
- Command Line Tooling
  - Offline Rendering (TVG -> TGA)
  - Format Conversion (SVG <-> TVG <-> TVGT)

## Building

The SDK is implemented with [Zig](https://ziglang.org/) 0.12.0 and [dotnet 6](https://dotnet.microsoft.com/en-us/).

To build the SDK (except `svg2tvgt`), do this:

```sh-session
[user@host sdk]$ cd src/tools/svg2tvgt/
[user@host sdk]$ zig build
[user@host sdk]$
```

This will then produce the folders `zig-cache` (for temporary files) and `zig-out`, which contains the SDK files for your current platform.

To build `svg2tvgt`, go into the folder `src/tools/svg2tvgt` and do this:

```sh-session
[user@host svg2tvgt]$ dotnet build
MSBuild version 17.3.2+561848881 for .NET
  Determining projects to restore...
  All projects are up-to-date for restore.
  svg2tvgt -> /mnt/src/tools/svg2tvgt/bin/Debug/net6.0/svg2tvgt.dll

Build succeeded.
    0 Warning(s)
    0 Error(s)

Time Elapsed 00:00:00.69
[user@host svg2tvgt]$
```

This will then produce `src/tools/svg2tvgt/bin/Debug/net6.0/svg2tvgt` (or `.exe` if you are on windows).
