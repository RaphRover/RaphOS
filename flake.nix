{
  description = "A flake to build a basic NixOS iso";

  inputs = { nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable"; };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = (import nixpkgs) { inherit system; };

      OSName = "RaphaOS";
      version = "0.1.0";

      OSImage = pkgs.callPackage ./RaphaOS-image { inherit OSName version; };

      bootstrapper = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs OSName OSImage version; };
        modules = [ ./bootstrapper-config ];
      };

    in {
      nixosConfigurations = { inherit bootstrapper; };

      packages.${system} = {
        inherit OSImage;
        default = bootstrapper.config.system.build.isoImage;
      };

      formatter.${system} = pkgs.nixfmt-classic;
    };
}
