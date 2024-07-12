{
  description = "A flake to build a basic NixOS iso";

  inputs = { nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable"; };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = (import nixpkgs) { inherit system; };

      RaphaOS-image = pkgs.callPackage ./RaphaOS-image { };

      bootstrapper = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs RaphaOS-image; };
        modules = [ ./bootstrapper-config ];
      };

    in {
      nixosConfigurations = { inherit bootstrapper; };

      packages.${system} = {
        inherit RaphaOS-image;
        default = bootstrapper.config.system.build.isoImage;
      };

      formatter.${system} = pkgs.nixfmt-classic;
    };
}
