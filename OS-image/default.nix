{ OSName, OSVersion, lib, pkgs, vmTools, fetchurl, stdenv, makeWrapper, ... }:
let
  imageSize = 8192;

  tools = import ./tools.nix { inherit lib pkgs; };

  files = pkgs.callPackage ./files { inherit OSName OSVersion; };

  scripts = pkgs.callPackage ./scripts { inherit files; };

  packageLists = let
    noble-updates-stamp = "20250710T120000Z";
    ros2-stamp = "2025-05-23";
    fictionlab-stamp = "2025-06-02";
  in [
    {
      name = "noble-main";
      packagesFile = (fetchurl {
        url = "mirror://ubuntu/dists/noble/main/binary-amd64/Packages.xz";
        sha256 = "sha256-KmoZnhAxpcJ5yzRmRtWUmT81scA91KgqqgMjmA3ZJFE=";
      });
      urlPrefix = "mirror://ubuntu";
    }
    {
      name = "noble-universe";
      packagesFile = (fetchurl {
        url = "mirror://ubuntu/dists/noble/universe/binary-amd64/Packages.xz";
        sha256 = "sha256-upBX+huRQ4zIodJoCNAMhTif4QHQwUliVN+XI2QFWZo=";
      });
      urlPrefix = "mirror://ubuntu";
    }
    {
      name = "noble-updates-main";
      packagesFile = (fetchurl {
        url =
          "http://snapshot.ubuntu.com/ubuntu/${noble-updates-stamp}/dists/noble-updates/main/binary-amd64/Packages.xz";
        sha256 = "sha256-oy2UzIbfgx3X3Eexi6izPeGQlT6W4bycDL/YRW/DvJY=";
      });
      urlPrefix = "http://snapshot.ubuntu.com/ubuntu/${noble-updates-stamp}";
    }
    {
      name = "noble-updates-universe";
      packagesFile = (fetchurl {
        url =
          "http://snapshot.ubuntu.com/ubuntu/${noble-updates-stamp}/dists/noble-updates/universe/binary-amd64/Packages.xz";
        sha256 = "sha256-IRWR+PLMCmITU7a9tngtcvFtg4xtQTy3+WFvC9oKC1A=";
      });
      urlPrefix = "http://snapshot.ubuntu.com/ubuntu/${noble-updates-stamp}";
    }
    {
      name = "ros2";
      packagesFile = (fetchurl {
        url =
          "http://snapshots.ros.org/jazzy/${ros2-stamp}/ubuntu/dists/noble/main/binary-amd64/Packages.bz2";
        sha256 = "sha256-M0fiaPJW8FqqfR8j8oSjRxgCXkoJD4COsrVBN9yMRLE=";
      });
      urlPrefix = "http://snapshots.ros.org/jazzy/${ros2-stamp}/ubuntu";
    }
    {
      name = "fictionlab";
      packagesFile = (fetchurl {
        url =
          "https://archive.fictionlab.pl/dists/noble/snapshots/${fictionlab-stamp}/main/binary-amd64/Packages.gz";
        sha256 = "sha256-9RghWT5jQ00AYy68C/4nh6pqC/L2i5EzERSogmK+PPw=";
      });
      urlPrefix = "https://archive.fictionlab.pl";
    }
  ];

  # Packages that provide programs needed to install other packages
  debs-unpack = import (tools.debClosureGenerator {
    name = "debs-unpack";
    inherit packageLists;
    packages = [
      "base-files"
      "dpkg"
      "libc-bin"
      "dash"
      "coreutils"
      "diffutils"
      "sed"
      "debconf"
      "perl"
    ];
  }) { inherit fetchurl; };

  debs-install = import (tools.debClosureGenerator {
    name = "debs-install";
    inherit packageLists;
    packages = [
      "base-passwd"
      "init-system-helpers"
      "grep"
      "base-files"
      "apt"
      "dpkg"
      "libc-bin"
      "bash"
      "dash"
      "coreutils"
      "diffutils"
      "sed"
      "login"
      "passwd"
      "debconf"
      "perl"
      "findutils"
      "curl"
      "patch"
      "locales"
      "util-linux"
      "file"
      "bsdutils"
      "less"
      "nano"
      "vim"

      "systemd" # init system
      "systemd-sysv" # provides systemd as /sbin/init
      "e2fsprogs" # initramfs wants fsck
      "zstd" # compress kernel using zstd
      "linux-image-generic" # kernel
      "grub-efi" # boot loader
      "initramfs-tools" # hooks for generating an initramfs

      "ncurses-base" # terminfo to let applications talk to terminals better
      "openssh-server" # Remote login
      "dbus" # networkctl

      "netplan.io"
      "iproute2"
      "iputils-ping"
      "systemd-resolved"
      "systemd-timesyncd"

      "ros-jazzy-ros-base"
      "ros-jazzy-micro-ros-agent"
      "ros-jazzy-rapha-robot"
    ];
  }) { inherit fetchurl; };

  debsClosure = closureInfo {
    rootPaths = lib.lists.flatten (debs-unpack ++ debs-install);
  };

in vmTools.runInLinuxVM (stdenv.mkDerivation {
  inherit name size debsClosure;

  debs_unpack = debs-unpack;

  debs = (lib.intersperse "|" debs-install);

  preVM = ''
    mkdir -p $out
    diskImage=$out/${name}.img
    ${pkgs.qemu_kvm}/bin/qemu-img create -f raw $diskImage "${toString size}M"
  '';

  buildCommand = ''
    ${scripts}/build.sh
  '';
})
