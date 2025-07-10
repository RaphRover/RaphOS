{
  description = "A flake to build a RaphOS bootstrapper and OS image";

  inputs = { nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable"; };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = (import nixpkgs) { inherit system; };

      OSName = "RaphOS";
      OSVersion = "0.0.0";

      OSImage = pkgs.callPackage ./OS-image { inherit OSName OSVersion; };

      bootstrapper = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs OSName OSImage OSVersion; };
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
