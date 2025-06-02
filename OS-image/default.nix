{ OSName, OSVersion, lib, pkgs, vmTools, fetchurl, stdenv, makeWrapper
, buildNpmPackage, ... }:
let
  imageSize = 8192;

  tools = import ./tools.nix { inherit lib pkgs; };

  ibis_ui = buildNpmPackage {
    pname = "ibis_ui";
    version = "1.5.1";
    src = builtins.fetchGit {
      url = "git@github.com:fictionlab-ibis/ibis_ui.git";
      rev = "4031da47e087c3fd9210dfd98d55239e8dcd044e";
    };
    npmDepsHash = "sha256-QQ1tCcxNn2T7d6Ho81lfSYditXgcLr36KZjF75x/5Vo=";
    makeCacheWritable = true;
    installPhase = ''
      mkdir $out
      cp -r build/* $out
    '';
  };

  files = pkgs.callPackage ./files { inherit OSName OSVersion ibis_ui; };

  scripts = pkgs.callPackage ./scripts { inherit files; };

  packageLists = let
    noble-updates-stamp = "20250529T120000Z";
    ros2-stamp = "2025-04-30";
    fictionlab-stamp = "2025-05-19";
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
        sha256 = "sha256-myf+XHunoDO9TuyyRzxgJcNm9yYqQnpJmWf/F/9zoq4=";
      });
      urlPrefix = "http://snapshot.ubuntu.com/ubuntu/${noble-updates-stamp}";
    }
    {
      name = "noble-updates-universe";
      packagesFile = (fetchurl {
        url =
          "http://snapshot.ubuntu.com/ubuntu/${noble-updates-stamp}/dists/noble-updates/universe/binary-amd64/Packages.xz";
        sha256 = "sha256-2NN94A4nAexjn6bNxvk5GHIuT6kFVLwx0nbaKqeihE0=";
      });
      urlPrefix = "http://snapshot.ubuntu.com/ubuntu/${noble-updates-stamp}";
    }
    {
      name = "ros2";
      packagesFile = (fetchurl {
        url =
          "http://snapshots.ros.org/jazzy/${ros2-stamp}/ubuntu/dists/noble/main/binary-amd64/Packages.bz2";
        sha256 = "sha256-e6f0jsqjDLxaSPLvVXYIl3FRNYCCnkigLRrpIhsfacM=";
      });
      urlPrefix = "http://snapshots.ros.org/jazzy/${ros2-stamp}/ubuntu";
    }
    {
      name = "fictionlab";
      packagesFile = (fetchurl {
        url =
          "https://archive.fictionlab.pl/dists/noble/snapshots/${fictionlab-stamp}/main/binary-amd64/Packages.gz";
        sha256 = "sha256-sUEm9kPAGgJlB6DLmNCbpeHHM8x9FKzUAodSqBur7zs=";
      });
      urlPrefix = "https://archive.fictionlab.pl";
    }
  ];

  debsClosure = import (tools.debClosureGenerator {
    name = "debs-closure";
    inherit packageLists;
    packages = [
      # STAGE 0 - predependencies
      "base-passwd"
      "base-files"
      "init-system-helpers"
      "dpkg"
      "libc-bin"
      "dash"
      "coreutils"
      "diffutils"
      "sed"
      "debconf"
      "perl"

      "---"

      # STAGE 1
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

      # Added here to fix a problem with deb closure generator which cannot properly
      # resolve dependencies like "python3-distro (>= 1.4.0) | python3 (<< 3.8)"
      "python3-distro"

      # Configures sources for ROS 2 repo
      "ros2-apt-source"

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

  exportStage = stageNr:
    pkgs.runCommand "debs-stage${toString stageNr}" { } ''
      echo "${
        toString (lib.intersperse "|" (builtins.elemAt debsClosure stageNr))
      }" > $out
    '';

  debsStage0 = exportStage 0;
  debsStage1 = exportStage 1;

in vmTools.runInLinuxVM (stdenv.mkDerivation {
  inherit OSName debsStage0 debsStage1;

  pname = "${OSName}-image";
  version = OSVersion;

  memSize = 4096;

  ibis_ros_src = builtins.fetchGit {
    url = "git@github.com:fictionlab-ibis/ibis_ros.git";
    rev = "8973104f64a750c202a374620a96f91ae637bdba";
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
    echo ${toString [ debsStage0 debsStage1 ]} > $out/nix-support/deb-inputs
  '';
})
