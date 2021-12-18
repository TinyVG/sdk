
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

Known problems:
  - x86_64-windows static library does not work with VisualStudio
  - macos dynamic library requires rpath patching
  - aarch64-macos doesn't have svg2tvgt
  - dynamic linking of static library doesn't work on void-musl
