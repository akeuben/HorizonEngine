{
    description = "GEARS Game";

    inputs.flake-utils.url = "github:numtide/flake-utils";
    inputs.zig.url = "github:mitchellh/zig-overlay";

    outputs = { self, nixpkgs, flake-utils, zig }: flake-utils.lib.eachDefaultSystem (system:
        let pkgs = nixpkgs.legacyPackages.${system}; in {
            devShells.default = import ./shell.nix { inherit pkgs zig; };
        }
    );
}
