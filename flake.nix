{
  description = "A flake to build a basic NixOS iso";
  inputs = { nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable"; };
  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = (import nixpkgs) { inherit system; };

      bootstrapper = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          (nixpkgs
            + "/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix")
          ./bootstrapper-config
        ];
      };

      RaphaOS-image = pkgs.callPackage ./RaphaOS-image { };

    in {
      nixosConfigurations = { inherit bootstrapper; };

      packages.${system} = {
        inherit RaphaOS-image;
        default = bootstrapper.config.system.build.isoImage;
      };

      formatter.${system} = pkgs.nixfmt-classic;
    };
}
