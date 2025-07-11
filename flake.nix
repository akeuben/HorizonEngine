{
    description = "GEARS Game";

    inputs.flake-utils.url = "github:numtide/flake-utils";
    inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    outputs = { self, nixpkgs, flake-utils }: flake-utils.lib.eachDefaultSystem (system:
        let pkgs = nixpkgs.legacyPackages.${system}; in {
            devShells.default = import ./shell.nix { inherit pkgs; };
        }
    );
}
