{
  OSName,
  OSVersion,
  imageBuilder,
  pkgs,
  fetchurl,
  ...
}:
let
  imageSize = 8192;
  memSize = 4096;

  files = pkgs.callPackage ./files { inherit OSName OSVersion; };

  scripts = pkgs.callPackage ./scripts { inherit files imageBuilder; };

  packageLists =
    let
      noble-updates-stamp = "20260313T120000Z";
      ros2-stamp = "2026-01-28";
      fictionlab-stamp = "2026-03-30";
    in
    [
      {
        name = "noble-main";
        packagesFile = (
          fetchurl {
            url = "mirror://ubuntu/dists/noble/main/binary-amd64/Packages.xz";
            sha256 = "sha256-KmoZnhAxpcJ5yzRmRtWUmT81scA91KgqqgMjmA3ZJFE=";
          }
        );
        urlPrefix = "mirror://ubuntu";
      }
      {
        name = "noble-universe";
        packagesFile = (
          fetchurl {
            url = "mirror://ubuntu/dists/noble/universe/binary-amd64/Packages.xz";
            sha256 = "sha256-upBX+huRQ4zIodJoCNAMhTif4QHQwUliVN+XI2QFWZo=";
          }
        );
        urlPrefix = "mirror://ubuntu";
      }
      {
        name = "noble-updates-main";
        packagesFile = (
          fetchurl {
            url = "http://snapshot.ubuntu.com/ubuntu/${noble-updates-stamp}/dists/noble-updates/main/binary-amd64/Packages.xz";
            sha256 = "sha256-HKkVlPgye9ZWosAhH/QHYbsQxFLv2TGS7FAF7ps+6sQ=";
          }
        );
        urlPrefix = "http://snapshot.ubuntu.com/ubuntu/${noble-updates-stamp}";
      }
      {
        name = "noble-updates-universe";
        packagesFile = (
          fetchurl {
            url = "http://snapshot.ubuntu.com/ubuntu/${noble-updates-stamp}/dists/noble-updates/universe/binary-amd64/Packages.xz";
            sha256 = "sha256-sCYnJUnCVBHuEYU47ZA1EbB1YPiumXv4q09EY7yP89A=";
          }
        );
        urlPrefix = "http://snapshot.ubuntu.com/ubuntu/${noble-updates-stamp}";
      }
      {
        name = "ros2";
        packagesFile = (
          fetchurl {
            url = "http://snapshots.ros.org/jazzy/${ros2-stamp}/ubuntu/dists/noble/main/binary-amd64/Packages.bz2";
            sha256 = "sha256-6U3UJEVPPz27vEfUwPalhbpML1DKUL98ofvUktdJ7Vw=";
          }
        );
        urlPrefix = "http://snapshots.ros.org/jazzy/${ros2-stamp}/ubuntu";
      }
      {
        name = "fictionlab";
        packagesFile = (
          fetchurl {
            url = "https://archive.fictionlab.pl/dists/noble/snapshots/${fictionlab-stamp}/main/binary-amd64/Packages.gz";
            sha256 = "sha256-4QLNplKdPIouOMhJEJYILncOldD+jvdEGbFDCPI3UGA=";
          }
        );
        urlPrefix = "https://archive.fictionlab.pl";
      }
    ];

  debsClosure = import (imageBuilder.mkDebClosureGenerator {
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

      # STAGE 1 - base packages
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
      "chrony" # SNTP client and server
      "avahi-daemon" # mDNS support
      "openssh-server" # Remote login
      "nginx" # Web server

      "---"

      # STAGE 2 - ROS base packages

      # Added here to fix a problem with deb closure generator which cannot properly
      # resolve dependencies like "python3-distro (>= 1.4.0) | python3 (<< 3.8)"
      "python3-distro"

      # Configures sources for ROS 2 repo
      "ros2-apt-source"

      # ROS build tools
      # "ros-dev-tools"
      # The newest ROS snapshot is missing ros-dev-tools, so we install its dependencies instead
      "build-essential"
      "cmake"
      "python3-setuptools"
      "python3-bloom"
      "python3-colcon-common-extensions"
      "python3-colcon-mixin"
      "python3-rosdep"
      "python3-vcstool"
      "wget"

      # ROS base packages
      "ros-jazzy-ros-base"

      "---"

      # STAGE 3 - Raph-specific packages

      "ros-jazzy-micro-ros-agent"
      "ros-jazzy-raph-robot"
      "raph-ui"
    ];
  }) { inherit fetchurl; };

  exportStage = stageNr: builtins.elemAt debsClosure stageNr;

  debsStage0 = exportStage 0;
  debsStage1 = exportStage 1;
  debsStage2 = exportStage 2;
  debsStage3 = exportStage 3;

  imageStages = imageBuilder.mkImageStageChain {
    name = "OS";
    inherit imageSize memSize;
    qemuImg = pkgs.qemu_kvm;
    logOutput = true;
    stages = [
      {
        name = "stage1";
        outputName = "OSStage1Image";
        script = scripts.stage1;
        env = { inherit debsStage0 debsStage1; };
        debInputs = [ debsStage0 debsStage1 ];
      }
      {
        name = "stage2";
        outputName = "OSStage2Image";
        script = scripts.stage2;
        env = { debsStage = debsStage2; };
        debInputs = [ debsStage2 ];
      }
      {
        name = "stage3";
        outputName = "OSStage3Image";
        script = scripts.stage3;
        env = { debsStage = debsStage3; };
        debInputs = [ debsStage3 ];
      }
      {
        name = "stage4";
        outputName = "OSStage4Image";
        script = scripts.stage4;
      }
    ];
  };
in
rec {
  OSStage1Image = imageStages.OSStage1Image;
  OSStage2Image = imageStages.OSStage2Image;
  OSStage3Image = imageStages.OSStage3Image;
  OSStage4Image = imageStages.OSStage4Image;

  OSLiteImage = imageBuilder.mkQcow2ImageStage {
    pname = "${OSName}-lite-image";
    version = OSVersion;
    inherit memSize;
    previousImage = OSStage4Image;
    script = scripts.stageFinal;
    logOutput = true;
    env = {
      inherit OSName OSVersion;
      OSVariant = "lite";
    };
  };

  OSLiteRawImage = imageBuilder.mkRawImage {
    image = OSLiteImage;
    osName = OSName;
    osVersion = OSVersion;
    variant = "lite";
    filename = "OS.img";
    repairGpt = true;
  };
}
