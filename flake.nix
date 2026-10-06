{
  description = "A flake to build a RaphOS bootstrapper and OS image";

  inputs = {
    nix-debian-image-builder.url = "github:fictionlab/nix-debian-image-builder";
    nixpkgs.follows = "nix-debian-image-builder/nixpkgs";
  };

  outputs =
    { self, nix-debian-image-builder, nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = (import nixpkgs) { inherit system; };

      OSName = "RaphOS";
      OSVersion = "1.0.0";

      OSImageDerivations = pkgs.lib.filterAttrs (_: v: pkgs.lib.isDerivation v) (
        pkgs.callPackage ./OS-image {
          inherit OSName OSVersion;
          imageBuilder = nix-debian-image-builder.lib system;
          buildSystem = system;
        }
      );

      bootstrapper-lite = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit
            inputs
            OSName
            OSVersion
            ;
          OSImage = OSImageDerivations.OSLiteRawImage;
          OSVariant = "lite";
        };
        modules = [ ./bootstrapper-config ];
      };

    in
    {
      nixosConfigurations = { inherit bootstrapper-lite; };

      packages.${system} = OSImageDerivations // rec {
        lite = bootstrapper-lite.config.system.build.isoImage;
        default = lite;
      };

      formatter.${system} = pkgs.nixfmt-tree;
    };
}
