{ pkgs ? import <nixpkgs> {} }:
  pkgs.mkShell {
    # nativeBuildInputs is usually what you want -- tools you need to run
    nativeBuildInputs = with pkgs; [ 
        # Build tools
        zig

        # Vulkan
        vulkan-tools 
        vulkan-loader 
        vulkan-headers 
        vulkan-validation-layers 
        spirv-tools 
        shaderc 

        # Linux Rendering libraries
        xorg.libX11
        xorg.libXxf86vm
        xorg.libXrandr
        xorg.libXi
        wayland
    ];
}

