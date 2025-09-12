{ pkgs ? import <nixpkgs> {} }:
  pkgs.mkShell {
    # nativeBuildInputs is usually what you want -- tools you need to run
    buildInputs = with pkgs; [ 
        # Build tools
        zig
        cmake
        dotnet-sdk_8

        # Vulkan
        vulkan-tools 
        vulkan-loader 
        vulkan-headers 
        vulkan-validation-layers 
        spirv-tools 
        shaderc 

        vulkan-validation-layers

        # Linux Rendering libraries
        wayland
        wayland-protocols
        wayland-scanner
        libxkbcommon
        xorg.libX11
        xorg.libXcursor
        xorg.libXxf86vm
        xorg.libXrandr
        xorg.libXi
        xorg.libXinerama
        libGL
    ];

    VULKAN_REGISTRY = "${pkgs.vulkan-headers}/share/vulkan/registry/vk.xml";
    WL_PROTOCOL = "${pkgs.wayland-protocols}/share/wayland-protocols";
    shellHook = let 
        runtimeLibraries = with pkgs; [
        wayland
        libxkbcommon
        xorg.libX11
        xorg.libXcursor
        xorg.libXxf86vm
        xorg.libXrandr
        xorg.libXi
        xorg.libXinerama
        libGL
        ];
        
    in ''
        export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath runtimeLibraries}:$LD_LIBRARY_PATH
        export VK_LAYER_PATH=${pkgs.vulkan-validation-layers}/share/vulkan/explicit_layer.d
    '';
}
