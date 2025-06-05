# KappaEngine v2
This is a data-driven game engine designed to create modable games. Written in ZIG.

This is still a WIP.

## Platform Support
Currently only supports Linux on X11. Planning support for Windows and Linux with wayland.

# Building
Clone the repository with submodules:
```
git clone --recursive https://akeuben.github.com/engine
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
