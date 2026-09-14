{
  description = "A flake to build a RaphOS bootstrapper and OS image";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = (import nixpkgs) { inherit system; };

      OSName = "RaphOS";
      OSVersion = "1.0.0";

      OSImageDerivations = pkgs.callPackage ./OS-image {
        inherit OSName OSVersion;
        buildSystem = system;
      };

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
