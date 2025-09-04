# HorizonEngine
<p align="center">
  <img src="assets/logo_dark.svg" width=300 />
</p>

A data-driven game engine designed to create modable games. Written in zig.

## Platform Support
Currently only supports Linux on X11 and  wayland. Support for windows will be added at a later time.

# Building
Clone the repository with submodules:
```
git clone --recursive https://akeuben.github.com/HorizonEngine
```

If you cloned without cloning submodules, use:
```
git submodule update --init --recursive
```
## Dependencies
The following dependencies are required:

- `zig v0.14.0`
- `cmake`
- `dotnet v8.0`
- `vulkan`
- `vulkan-headers`
- `shaderc`
- `wayland`
- `wayland-protocols`
- `wayland-scanner`
- `libxkbcommon`
- `libX11`
- `libXcursor`
- `libXxf86vm`
- `libXrandr`
- `libXi`
- `libXinerama`
- `libGL`

All dependencies can be installed if the [nix](https://nixos.org) package manager.
Simply use the flake with `nix develop`.

## Building 
This project uses the `zig` build system. Run 
```
zig build
```
to compile the engine and runtime. Immediately run the application with 
```
zig build run -- [backend]
```

The following `[backend]` options are available:

| `[backend]` | Description                                                        |
|-------------|--------------------------------------------------------------------|
| `vk`        | Uses the Vulkan backend                                            |
| `gl`        | Uses the OpenGL backend                                            |
| `none`      | Uses a null backend without graphics output                        |
