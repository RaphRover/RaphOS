{
  OSName,
  OSVersion,
  lib,
  pkgs,
  vmTools,
  fetchurl,
  stdenv,
  ...
}:
let
  imageSize = 8192;
  memSize = 4096;

  tools = import ./tools.nix { inherit lib pkgs; };

  files = pkgs.callPackage ./files { inherit OSName OSVersion; };

  scripts = pkgs.callPackage ./scripts { inherit files; };

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

  exportStage = stageNr: map toString (builtins.elemAt debsClosure stageNr);

  debsStage0 = exportStage 0;
  debsStage1 = exportStage 1;
  debsStage2 = exportStage 2;
  debsStage3 = exportStage 3;

  # QEMU drops console output under nix-build, so the build logs to
  # xchg/build.log instead, tailed here on the host. Tail gets its own
  # private fd (3) so QEMU can't make it non-blocking and kill it with EAGAIN.
  vmLogPrepareCommand = ''
    touch xchg/build.log
    exec 3>/proc/self/fd/1
    tail -n +1 -f xchg/build.log >&3 &
    tailPid=$!
    trap 'kill "$tailPid" 2>/dev/null || true' EXIT
  '';
in
rec {
  OSStage1Image = vmTools.runInLinuxVM (
    stdenv.mkDerivation {
      inherit memSize debsStage0 debsStage1;

      pname = "OS-stage1-image";
      version = "";

      preVM = ''
        mkdir -p $out
        diskImage=$out/OS.img
        ${pkgs.qemu_kvm}/bin/qemu-img create -f qcow2 $diskImage "${toString imageSize}M"

        touch xchg/build.log
        exec 3>/proc/self/fd/1
        tail -n +1 -f xchg/build.log >&3 &
        tailPid=$!
        trap 'kill "$tailPid" 2>/dev/null || true' EXIT
      '';

      buildCommand = ''
        ${scripts.stage1}/build.sh > /tmp/xchg/build.log 2>&1
        mkdir -p "$out/nix-support"
        echo ${
          toString [
            debsStage0
            debsStage1
          ]
        } > $out/nix-support/deb-inputs
      '';

      #   postVM = ''
      #     # Shrink the disk image
      #     LAST_SECTOR=$(${pkgs.parted}/bin/parted $diskImage -ms unit s print | tail -n +3 | cut -d: -f3 | sed 's/s//' | sort -n | tail -1)
      #     GPT_BACKUP_TABLE_SECTORS=34
      #     SECTOR_SIZE=512
      #     DISK_SIZE=$(( (LAST_SECTOR + GPT_BACKUP_TABLE_SECTORS) * SECTOR_SIZE ))

      #     ${pkgs.qemu_kvm}/bin/qemu-img resize --shrink -f raw $diskImage $DISK_SIZE
      #     ${pkgs.gptfdisk}/bin/sgdisk -e $diskImage
      #   '';
    }
  );

  OSStage2Image = vmTools.runInLinuxVM (
    stdenv.mkDerivation {
      inherit memSize debsStage2;

      pname = "OS-stage2-image";
      version = "";

      preVM = ''
        mkdir -p $out
        diskImage=$out/OS.img
        ${pkgs.qemu_kvm}/bin/qemu-img create \
          -o backing_file=${OSStage1Image}/OS.img,backing_fmt=qcow2 \
          -f qcow2 $diskImage

        ${vmLogPrepareCommand}
      '';

      buildCommand = ''
        ${scripts.stage2}/build.sh > /tmp/xchg/build.log 2>&1

        mkdir -p $out/nix-support
        echo ${OSStage1Image}/OS.img > $out/nix-support/backing_image
        echo ${toString debsStage2} > $out/nix-support/deb-inputs
      '';
    }
  );

  OSStage3Image = vmTools.runInLinuxVM (
    stdenv.mkDerivation {
      inherit memSize debsStage3;

      pname = "OS-stage3-image";
      version = "";

      preVM = ''
        mkdir -p $out
        diskImage=$out/OS.img
        ${pkgs.qemu_kvm}/bin/qemu-img create \
          -o backing_file=${OSStage2Image}/OS.img,backing_fmt=qcow2 \
          -f qcow2 $diskImage

        ${vmLogPrepareCommand}
      '';

      buildCommand = ''
        ${scripts.stage3}/build.sh > /tmp/xchg/build.log 2>&1

        mkdir -p $out/nix-support
        echo ${OSStage2Image}/OS.img > $out/nix-support/backing_image
        echo ${toString debsStage3} > $out/nix-support/deb-inputs
      '';
    }
  );

  OSStage4Image = vmTools.runInLinuxVM (
    stdenv.mkDerivation {
      inherit memSize;

      pname = "OS-stage4-image";
      version = "";

      preVM = ''
        mkdir -p $out
        diskImage=$out/OS.img
        ${pkgs.qemu_kvm}/bin/qemu-img create \
          -o backing_file=${OSStage3Image}/OS.img,backing_fmt=qcow2 \
          -f qcow2 $diskImage

        ${vmLogPrepareCommand}
      '';

      buildCommand = ''
        ${scripts.stage4}/build.sh > /tmp/xchg/build.log 2>&1

        mkdir -p $out/nix-support
        echo ${OSStage3Image}/OS.img > $out/nix-support/backing_image
      '';
    }
  );

  OSLiteImage = vmTools.runInLinuxVM (
    stdenv.mkDerivation rec {
      inherit OSName OSVersion memSize;
      OSVariant = "lite";

      pname = "${OSName}-${OSVariant}-image";
      version = OSVersion;

      preVM = ''
        mkdir -p $out
        diskImage=$out/OS.img
        ${pkgs.buildPackages.qemu_kvm}/bin/qemu-img create \
          -o backing_file=${OSStage4Image}/OS.img,backing_fmt=qcow2 \
          -f qcow2 $diskImage
        ${vmLogPrepareCommand}
      '';

      buildCommand = ''
        ${scripts.stageFinal}/build.sh > /tmp/xchg/build.log 2>&1

        mkdir -p $out/nix-support
        echo ${OSStage4Image}/OS.img > $out/nix-support/backing_image
      '';
    }
  );

  OSLiteRawImage = stdenv.mkDerivation rec {
    OSVariant = "lite";

    pname = "${OSName}-${OSVariant}-raw-image";
    version = OSVersion;

    buildCommand = ''
      mkdir -p $out
      diskImage=$out/OS.img
      ${pkgs.buildPackages.qemu_kvm}/bin/qemu-img convert -f qcow2 -O raw \
        ${OSLiteImage}/OS.img $diskImage

      LAST_SECTOR=$(${pkgs.parted}/bin/parted $diskImage -ms unit s print | tail -n +3 | cut -d: -f3 | sed 's/s//' | sort -n | tail -1)
      SECTOR_SIZE=512
      DISK_SIZE=$(( (LAST_SECTOR + 1) * SECTOR_SIZE ))

      ${pkgs.buildPackages.qemu_kvm}/bin/qemu-img resize --shrink -f raw $diskImage $DISK_SIZE
    '';
  };
}
