{ lib, pkgs, vmTools, fetchurl, stdenv, makeWrapper, closureInfo, ... }:
let
  name = "RaphaOS";
  size = 8192;

  tools = import ./tools.nix { inherit lib pkgs; };

  files = stdenv.mkDerivation {
    name = "files";
    src = ./files;
    phases = [ "unpackPhase" "installPhase" ];
    installPhase = ''
      mkdir -p $out
      cp -vr $src/* $out
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

  packageLists = [
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
      name = "ros2";
      packagesFile = (fetchurl {
        url =
          "http://packages.ros.org/ros2-testing/ubuntu/dists/noble/main/binary-amd64/Packages.gz";
        sha256 = "sha256-S5tEJXzROSBTL0CKZhXDUID6qprd7/CiFZdYjmMTB7Q=";
      });
      urlPrefix = "http://packages.ros.org/ros2-testing/ubuntu";
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
