{ pkgs ? import <nixpkgs> {} }:
  pkgs.mkShell {
    # nativeBuildInputs is usually what you want -- tools you need to run
    buildInputs = with pkgs; [ 
        # Build tools
        zig_0_15
        dotnet-sdk_8

        # Vulkan
        shaderc 

        # Linux Rendering libraries
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
