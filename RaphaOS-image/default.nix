{ lib, pkgs, vmTools, fetchurl, stdenv, makeWrapper, ... }:
let
  name = "RaphaOS";
  size = 8192;

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

  packagesLists = [
    (fetchurl {
      url = "mirror://ubuntu/dists/noble/main/binary-amd64/Packages.xz";
      sha256 = "sha256-KmoZnhAxpcJ5yzRmRtWUmT81scA91KgqqgMjmA3ZJFE=";
    })
    (fetchurl {
      url = "mirror://ubuntu/dists/noble/universe/binary-amd64/Packages.xz";
      sha256 = "sha256-upBX+huRQ4zIodJoCNAMhTif4QHQwUliVN+XI2QFWZo=";
    })
  ];
  urlPrefix = "mirror://ubuntu";

  debs_preunpack = import (vmTools.debClosureGenerator {
    name = "preunpack";
    inherit packagesLists urlPrefix;
    packages = [
      "base-files"
      "apt"
      "dpkg"
      "libc-bin"
      "dash"
      "coreutils"
      "diffutils"
      "sed"
      "login"
      "passwd"
      "debconf"
      "perl"
    ];
  }) { inherit fetchurl; };

  debs-stage1 = import (vmTools.debClosureGenerator {
    name = "stage1";
    inherit packagesLists urlPrefix;
    packages = [ "base-passwd" "init-system-helpers" "grep" ];
  }) { inherit fetchurl; };

  debs-stage2 = import (vmTools.debClosureGenerator {
    name = "stage2";
    inherit packagesLists urlPrefix;
    packages = [
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

      "systemd" # init system
      "systemd-sysv" # provides systemd as /sbin/init
      "linux-image-generic" # kernel
      "initramfs-tools" # hooks for generating an initramfs
      "e2fsprogs" # initramfs wants fsck
      "grub-efi" # boot loader
      "zstd" # compress kernel using zstd

      "apt" # package manager
      "ncurses-base" # terminfo to let applications talk to terminals better
      "openssh-server" # Remote login
      "dbus" # networkctl
    ];
  }) { inherit fetchurl; };

in vmTools.runInLinuxVM (stdenv.mkDerivation {
  inherit name size;

  inherit debs_preunpack;

  debs = (lib.intersperse "|" [ debs-stage1 debs-stage2 ]);

  preVM = vmTools.createEmptyImage {
    inherit size;
    fullName = name;
  };

  buildCommand = ''
    ${scripts}/build.sh
  '';
})
