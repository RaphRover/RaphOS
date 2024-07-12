{ config, lib, pkgs, inputs, RaphaOS-image, ... }:

{
  imports = [
    (inputs.nixpkgs
      + "/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix")
  ];

  networking.hostName = "bootstrapper";

  time.timeZone = "Europe/London";

  isoImage = {
    isoBaseName = "RaphaOS-Bootstrapper";
    makeBiosBootable = false;
    makeEfiBootable = true;
    squashfsCompression = "zstd";
    storeContents = lib.mkAfter [ RaphaOS-image ];
  };

  boot.loader.grub.memtest86.enable = lib.mkForce false;
  boot.loader.timeout = lib.mkForce 0;

  services.openssh.enable = lib.mkForce false;

  networking.wireless.enable = false;
  networking.firewall.enable = false;
  networking.useDHCP = false;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  # environment.systemPackages = with pkgs; [
  #   vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #   wget
  # ];

  system.stateVersion = "24.05";
}

