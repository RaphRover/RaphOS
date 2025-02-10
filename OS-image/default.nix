{ OSName, OSVersion, lib, pkgs, vmTools, fetchurl, stdenv, makeWrapper
, buildNpmPackage, ... }:
let
  imageSize = 8192;

  tools = import ./tools.nix { inherit lib pkgs; };

  ibis_ui = buildNpmPackage {
    pname = "ibis_ui";
    version = "1.3.0";
    src = builtins.fetchGit {
      url = "git@github.com:fictionlab-ibis/ibis_ui.git";
      rev = "9a04562017207789f4ca90ff3d4014978149bd49";
    };
    npmDepsHash = "sha256-mIkqhtZXy6K15A1I4tnCIY1IAznJqvGqQT5ZDHYV9NY=";
    makeCacheWritable = true;
    installPhase = ''
      mkdir $out
      cp -r build/* $out
    '';
  };

  files = pkgs.callPackage ./files { inherit OSName OSVersion ibis_ui; };

  scripts = pkgs.callPackage ./scripts { inherit files; };

  packageLists = let
    noble-updates-stamp = "20250210T120000Z";
    ros2-stamp = "2025-01-20";
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
        sha256 = "sha256-n4N/7bPBtnIwSajCLEfK+hlk3h76xyPAfLwnhX4xigs=";
      });
      urlPrefix = "http://snapshot.ubuntu.com/ubuntu/${noble-updates-stamp}";
    }
    {
      name = "noble-updates-universe";
      packagesFile = (fetchurl {
        url =
          "http://snapshot.ubuntu.com/ubuntu/${noble-updates-stamp}/dists/noble-updates/universe/binary-amd64/Packages.xz";
        sha256 = "sha256-lPnkRdS6OcxSGQMnSu6V521S3QF4fBvQiDFDoWr0Bp4=";
      });
      urlPrefix = "http://snapshot.ubuntu.com/ubuntu/${noble-updates-stamp}";
    }
    {
      name = "ros2";
      packagesFile = (fetchurl {
        url =
          "http://snapshots.ros.org/jazzy/${ros2-stamp}/ubuntu/dists/noble/main/binary-amd64/Packages.bz2";
        sha256 = "sha256-oCoKPBQKAwYMQ4tzPWEMOaQ5ZiJ82TLDPGrwUw3fr6I=";
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
      "policykit-1" # authorization manager for systemd
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
  inherit OSName debs_unpack debs_install;

  pname = "${OSName}-image";
  version = OSVersion;

  memSize = 4096;

  ibis_ros_src = builtins.fetchGit {
    url = "git@github.com:fictionlab-ibis/ibis_ros.git";
    rev = "c727ed2e90f79fa5db403df3f281c38851141622";
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
