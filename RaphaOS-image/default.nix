{ lib, pkgs, vmTools, fetchurl, stdenv, makeWrapper, ... }:
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
      mkdir -p $out/usr/share/keyrings
      cp -v ${ros-archive-keyring} $out/usr/share/keyrings/ros-archive-keyring.gpg
      cp -v ${fictionlab-archive-keyring} $out/usr/share/keyrings/fictionlab-archive-keyring.gpg

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

  packageLists = let
    noble-updates-stamp = "20241117T120000Z";
    ros2-stamp = "2024-10-18";
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
        sha256 = "sha256-+Vhz0cX9RD3CCquiYArxjUoCFX/yxHfK7afKCAaQqwI=";
      });
      urlPrefix = "http://snapshot.ubuntu.com/ubuntu/${noble-updates-stamp}";
    }
    {
      name = "noble-updates-universe";
      packagesFile = (fetchurl {
        url =
          "http://snapshot.ubuntu.com/ubuntu/${noble-updates-stamp}/dists/noble-updates/universe/binary-amd64/Packages.xz";
        sha256 = "sha256-JVmeMLgM7aHr2cGepvIP+76DlmYVEm+CB4yTOlEXiUk=";
      });
      urlPrefix = "http://snapshot.ubuntu.com/ubuntu/${noble-updates-stamp}";
    }
    {
      name = "ros2";
      packagesFile = (fetchurl {
        url =
          "http://snapshots.ros.org/jazzy/${ros2-stamp}/ubuntu/dists/noble/main/binary-amd64/Packages.bz2";
        sha256 = "sha256-i4Br7Ihgqg/sIYBEQzt9NbKfzjOJfzp5iwi81wObj4E=";
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
  debs-unpack-closure = import (tools.debClosureGenerator {
    name = "debs-unpack-closure";
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

  debs_unpack = pkgs.runCommand "debs-unpack" { } ''
    echo "${toString debs-unpack-closure}" > $out
  '';

  debs-install-closure = import (tools.debClosureGenerator {
    name = "debs-install-closure";
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
      "sudo"
      "dbus" # IPC used by various applications
      "ncurses-base" # terminfo to let applications talk to terminals better
      "bash-completion"
      "htop"

      # Boot stuff
      "systemd" # init system
      "systemd-sysv" # provides systemd as /sbin/init
      "libpam-systemd" # makes systemd user sevices work
      "e2fsprogs" # initramfs wants fsck
      "zstd" # compress kernel using zstd
      "linux-image-generic" # kernel
      "grub-efi" # boot loader
      "initramfs-tools" # hooks for generating an initramfs

      # Networking stuff
      "netplan.io" # network configuration utility
      "iproute2" # ip cli utilities
      "iputils-ping" # ping utility
      "systemd-resolved" # DNS resolver
      "systemd-timesyncd" # SNTP client
      "avahi-daemon" # mDNS support
      "openssh-server" # Remote login
      "networkd-dispatcher" # Networkd hooks

      # ROS build tools
      "ros-dev-tools"
      "python3-colcon-common-extensions"

      # ROS base packages
      "ros-jazzy-ros-base"
      "ros-jazzy-micro-ros-agent"

      # ibis_ros dependencies
      "ros-jazzy-async-web-server-cpp"
      "ros-jazzy-robot-state-publisher"
      "ros-jazzy-rosbridge-server"
      "ros-jazzy-cv-bridge"
      "ros-jazzy-depthai"
      "ros-jazzy-depthai-bridge"
      "ros-jazzy-generate-parameter-library"
      "ros-jazzy-pcl-ros"
      "ros-jazzy-pcl-conversions"
      "libpcl-dev"
      "libapr1-dev"
      "libaprutil1-dev"
      "ffmpeg"
    ];
  }) { inherit fetchurl; };

  debs_install = pkgs.runCommand "debs-install" { } ''
    echo "${toString (lib.intersperse "|" debs-install-closure)}" > $out
  '';

in vmTools.runInLinuxVM (stdenv.mkDerivation {
  inherit name size debs_unpack debs_install;

  memSize = 4096;

  ibis_ros_src = builtins.fetchGit {
    url = "git@github.com:fictionlab-ibis/ibis_ros.git";
    rev = "5e7cdbcdc7893f94aed2c7166d2e92acb480c2d1";
    submodules = true;
  };

  preVM = ''
    mkdir -p $out
    diskImage=$out/${name}.img
    ${pkgs.qemu_kvm}/bin/qemu-img create -f raw $diskImage "${toString size}M"
  '';

  buildCommand = ''
    ${scripts}/build.sh
    mkdir -p "$out/nix-support"
    echo ${toString [ debs_unpack debs_install ]} > $out/nix-support/deb-inputs
  '';
})
