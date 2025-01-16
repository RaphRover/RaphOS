{ OSName, version, lib, pkgs, vmTools, fetchurl, stdenv, makeWrapper
, buildNpmPackage, ... }:
let
  imageSize = 8192;

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

    ibis_ui = buildNpmPackage {
      pname = "ibis_ui";
      version = "1.1.0";
      src = builtins.fetchGit {
        url = "git@github.com:fictionlab-ibis/ibis_ui.git";
        rev = "5d07e57f12e9c67fa54f514f21a052474424720f";
      };
      npmDepsHash = "sha256-QXSjLFmh1HJHMzb8Xb3d7YqDPix40/WIxD05Md5Eud0=";
      makeCacheWritable = true;
      installPhase = ''
        mkdir $out
        cp -r build/* $out
      '';
    };

  in stdenv.mkDerivation {
    name = "files";
    src = ./files;
    phases = [ "unpackPhase" "installPhase" ];
    installPhase = ''
      mkdir -p $out/usr/share/keyrings
      cp -v ${ros-archive-keyring} $out/usr/share/keyrings/ros-archive-keyring.gpg
      cp -v ${fictionlab-archive-keyring} $out/usr/share/keyrings/fictionlab-archive-keyring.gpg

      mkdir -p $out/opt
      cp -vr ${ibis_ui} $out/opt/ibis_ui

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
    noble-updates-stamp = "20250101T120000Z";
    ros2-stamp = "2024-11-21";
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
        sha256 = "sha256-fwzEaIVoPobPL1YJ+CEtUVZOsdiuQtdHOzk+xNeGvKY=";
      });
      urlPrefix = "http://snapshot.ubuntu.com/ubuntu/${noble-updates-stamp}";
    }
    {
      name = "noble-updates-universe";
      packagesFile = (fetchurl {
        url =
          "http://snapshot.ubuntu.com/ubuntu/${noble-updates-stamp}/dists/noble-updates/universe/binary-amd64/Packages.xz";
        sha256 = "sha256-5aNIRoNKv14lvKFmyslolLJgLzXRplw8IMcDKGWH2nk=";
      });
      urlPrefix = "http://snapshot.ubuntu.com/ubuntu/${noble-updates-stamp}";
    }
    {
      name = "ros2";
      packagesFile = (fetchurl {
        url =
          "http://snapshots.ros.org/jazzy/${ros2-stamp}/ubuntu/dists/noble/main/binary-amd64/Packages.bz2";
        sha256 = "sha256-V7Law/wG7M4+Dr+8PCtW3eNYe9YNKhHme2BRbSudXh8=";
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
      "nginx" # Web server

      # ROS build tools
      "ros-dev-tools"
      "python3-colcon-common-extensions"

      # ROS base packages
      "ros-jazzy-ros-base"
      "ros-jazzy-micro-ros-agent"

      # ibis_ros dependencies
      "ros-jazzy-compressed-image-transport"
      "ros-jazzy-cv-bridge"
      "ros-jazzy-depthai"
      "ros-jazzy-depthai-bridge"
      "ros-jazzy-generate-parameter-library"
      "ros-jazzy-imu-complementary-filter"
      "ros-jazzy-mavlink"
      "ros-jazzy-pcl-ros"
      "ros-jazzy-pcl-conversions"
      "ros-jazzy-pybind11-vendor"
      "ros-jazzy-robot-state-publisher"
      "ros-jazzy-rosbag2-py"
      "ros-jazzy-rosbag2-storage-mcap"
      "ros-jazzy-rosbridge-server"
      "ros-jazzy-web-video-server"
      "ros-jazzy-xacro"
      "libapr1-dev"
      "libaprutil1-dev"
      "libavcodec-dev"
      "libavdevice-dev"
      "libavfilter-dev"
      "libavformat-dev"
      "libavutil-dev"
      "libpcl-dev"
      "libpostproc-dev"
      "libswresample-dev"
      "libswscale-dev"
      "python3-piexif"
      "python3-serial"
      "python3-yaml"
    ];
  }) { inherit fetchurl; };

  debs_install = pkgs.runCommand "debs-install" { } ''
    echo "${toString (lib.intersperse "|" debs-install-closure)}" > $out
  '';

in vmTools.runInLinuxVM (stdenv.mkDerivation {
  inherit OSName version debs_unpack debs_install;

  pname = "${OSName}-image";

  memSize = 4096;

  ibis_ros_src = builtins.fetchGit {
    url = "git@github.com:fictionlab-ibis/ibis_ros.git";
    rev = "2ac132ac58ac74ae41b2dca1e12dab46a9e7688a";
    submodules = true;
  };

  preVM = ''
    mkdir -p $out
    diskImage=$out/OS.img
    ${pkgs.qemu_kvm}/bin/qemu-img create -f raw $diskImage "${
      toString imageSize
    }M"
  '';

  buildCommand = ''
    ${scripts}/build.sh
    mkdir -p "$out/nix-support"
    echo ${toString [ debs_unpack debs_install ]} > $out/nix-support/deb-inputs
  '';
})
