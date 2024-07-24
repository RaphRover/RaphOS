{ lib, pkgs, vmTools, fetchurl, stdenv, makeWrapper, closureInfo, ... }:
let
  name = "RaphaOS";
  size = 8192;

  tools = import ./tools.nix { inherit lib pkgs; };

  files = let
    ros-archive-keyring = (fetchurl {
      url = "https://raw.githubusercontent.com/ros/rosdistro/master/ros.key";
      sha256 = "sha256-OkyNWeOg+7Ks8ziZS2ECxbqhcHHEzJf1ILSCppf4pP4=";
    });
    fictionlab-archive-keyring = (fetchurl {
      url = "https://files.fictionlab.pl/repo/fictionlab.gpg";
      sha256 = "sha256-noqi5NcMDrnwMp9JFVUrLJkH65WH9/EDISQIVT8Hnf8=";
    });
  in stdenv.mkDerivation {
    name = "files";
    src = ./files;
    phases = [ "unpackPhase" "installPhase" ];
    installPhase = ''
      mkdir -p $out
      cp -vr $src/* $out

      mkdir -p $out/usr/share/keyrings
      cp -v ${ros-archive-keyring} $out/usr/share/keyrings/ros-archive-keyring.gpg
      cp -v ${fictionlab-archive-keyring} $out/usr/share/keyrings/fictionlab-archive-keyring.gpg
    '';
  };

  scripts = stdenv.mkDerivation {
    name = "scripts";
    src = ./scripts;
    nativeBuildInputs = [ makeWrapper ];
    phases = [ "unpackPhase" "installPhase" "postFixup" ];
    installPhase = ''
      mkdir -p $out
      cp -vr $src/* $out
    '';
    postFixup = ''
      wrapProgram $out/build.sh \
      --set PATH "${
        with pkgs;
        lib.makeBinPath [
          gptfdisk
          util-linux
          dosfstools
          e2fsprogs
          dpkg
          coreutils
          gnutar
          systemd
        ]
      }" \
      --set FILES_DIR ${files} \
      --set NIX_STORE_DIR ${builtins.storeDir} \
      --set UDEVD "${pkgs.systemd}/lib/systemd/systemd-udevd"
    '';
  };

  packageLists = let
    noble-updates-stamp = "20240712T160000Z";
    ros2-stamp = "2024-07-05";
    fictionlab-stamp = "2024-07-22";
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
        sha256 = "sha256-r+aT6l2JLPjYUY2aibMnK+1u/+GiXxdkBe5pG4T/wbw=";
      });
      urlPrefix = "http://snapshot.ubuntu.com/ubuntu/${noble-updates-stamp}";
    }
    {
      name = "noble-updates-universe";
      packagesFile = (fetchurl {
        url =
          "http://snapshot.ubuntu.com/ubuntu/${noble-updates-stamp}/dists/noble-updates/universe/binary-amd64/Packages.xz";
        sha256 = "sha256-M//woptAt/o1bPtdtetWICD2gH+ZVSHGT1stOgZoAEU=";
      });
      urlPrefix = "http://snapshot.ubuntu.com/ubuntu/${noble-updates-stamp}";
    }
    {
      name = "ros2";
      packagesFile = (fetchurl {
        url =
          "http://snapshots.ros.org/jazzy/${ros2-stamp}/ubuntu/dists/noble/main/binary-amd64/Packages.bz2";
        sha256 = "sha256-R3SqO8YCwnDxEcTBh1xJHV9hnUjNcPuJ8OK1N/F6bOU=";
      });
      urlPrefix = "http://snapshots.ros.org/jazzy/${ros2-stamp}/ubuntu";
    }
    {
      name = "fictionlab";
      packagesFile = (fetchurl {
        url =
          "http://files.fictionlab.pl/repo/dists/noble/snapshots/${fictionlab-stamp}/main/binary-amd64/Packages.gz";
        sha256 = "sha256-6Xp5LlgN/V7sownWX0a5ePgnknEqjlA45684hms8pEo=";
      });
      urlPrefix = "http://files.fictionlab.pl/repo";
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
