{ OSName, OSImage, OSVersion, lib, pkgs, inputs, ... }:

{
  imports = [
    (inputs.nixpkgs
      + "/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix")
  ];

  networking.hostName = "bootstrapper";

  time.timeZone = "Europe/London";

  isoImage = {
    isoName = lib.mkForce "${OSName}-bootstrapper-${OSVersion}.iso";
    makeBiosBootable = false;
    makeEfiBootable = true;
    squashfsCompression = "zstd";
  };

  boot.loader.grub.memtest86.enable = lib.mkForce false;
  boot.loader.timeout = lib.mkForce 0;

  services.openssh.enable = lib.mkForce false;

  networking.wireless.enable = false;
  networking.firewall.enable = false;
  networking.useDHCP = false;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs;
    [
      (stdenv.mkDerivation {
        name = "bootstrapper-scripts";
        src = ./scripts;

        nativeBuildInputs = [ bash makeWrapper ];

        buildPhase = ''
          mkdir -p $out/bin
          install -t $out/bin ./install-os
        '';

        postFixup = ''
          wrapProgram $out/bin/install-os \
            --set PATH ${
              lib.makeBinPath [
                coreutils
                dmidecode
                e2fsprogs
                gptfdisk
                inotify-tools
                (python312Packages.python.withPackages (ps: [ ps.pyparted ]))
                util-linuxMinimal
              ]
            } --set OS_IMG_FILE "${OSImage}/OS.img"
        '';
      })
    ];

  users.users.nixos.shell = pkgs.stdenv.mkDerivation {
    name = "bootstrapper-sh";
    src = ./scripts;

    nativeBuildInputs = [ pkgs.bash ];

    buildPhase = ''
      mkdir -p $out/bin
      install -t $out/bin ./bootstrapper-sh
    '';

    passthru = { shellPath = "/bin/bootstrapper-sh"; };
  };

  system.stateVersion = "24.05";
}

