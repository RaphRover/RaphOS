{ OSName, OSVersion, lib, pkgs, vmTools, fetchurl, stdenv, buildNpmPackage, ...
}:
let
  imageSize = 8192;

  tools = import ./tools.nix { inherit lib pkgs; };

  raph_common_src = builtins.fetchGit {
    url = "https://github.com/RaphRover/raph_common.git";
    rev = "30322d5e88846829d93db0dbd2b9b8ebdf051baf";
  };

  raph_robot_src = builtins.fetchGit {
    url = "https://github.com/RaphRover/raph_robot.git";
    rev = "5c17ece31f17da4c266da8b7aca4fe26b181ec74";
  };

  # To update the raph_ui version, change the `rev` to the desired commit hash and clean the
  # `npmDepsHash` field. Then, start a nix build; it will fail and print the new hash to use.
  # After updating the hash, you can run the build again.
  raph_ui = buildNpmPackage {
    pname = "raph_ui";
    version = "1.0.0";
    src = builtins.fetchGit {
      url = "https://github.com/RaphRover/raph_ui.git";
      rev = "68f74cc227a82904e9a4c77474f8698f971583ec";
    };
    npmDepsHash = "sha256-1ZwfeXmLuO/HDBW3uFgJ0vQ6lhy0HT4+QTHkzpo6uA4=";
    makeCacheWritable = true;
    installPhase = ''
      mkdir $out
      cp -r dist/* $out
    '';
  };

  files = pkgs.callPackage ./files { inherit OSName OSVersion raph_ui; };

  scripts = pkgs.callPackage ./scripts { inherit files; };

  packageLists = let
    noble-updates-stamp = "20260313T120000Z";
    ros2-stamp = "2026-01-28";
    fictionlab-stamp = "2026-01-26";
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
        sha256 = "sha256-HKkVlPgye9ZWosAhH/QHYbsQxFLv2TGS7FAF7ps+6sQ=";
      });
      urlPrefix = "http://snapshot.ubuntu.com/ubuntu/${noble-updates-stamp}";
    }
    {
      name = "noble-updates-universe";
      packagesFile = (fetchurl {
        url =
          "http://snapshot.ubuntu.com/ubuntu/${noble-updates-stamp}/dists/noble-updates/universe/binary-amd64/Packages.xz";
        sha256 = "sha256-sCYnJUnCVBHuEYU47ZA1EbB1YPiumXv4q09EY7yP89A=";
      });
      urlPrefix = "http://snapshot.ubuntu.com/ubuntu/${noble-updates-stamp}";
    }
    {
      name = "ros2";
      packagesFile = (fetchurl {
        url =
          "http://snapshots.ros.org/jazzy/${ros2-stamp}/ubuntu/dists/noble/main/binary-amd64/Packages.bz2";
        sha256 = "sha256-6U3UJEVPPz27vEfUwPalhbpML1DKUL98ofvUktdJ7Vw=";
      });
      urlPrefix = "http://snapshots.ros.org/jazzy/${ros2-stamp}/ubuntu";
    }
    {
      name = "fictionlab";
      packagesFile = (fetchurl {
        url =
          "https://archive.fictionlab.pl/dists/noble/snapshots/${fictionlab-stamp}/main/binary-amd64/Packages.gz";
        sha256 = "sha256-Xo51B4ihxLRoXaQmRvWhOecuGlUzxw3e8FKQ8aLEk88=";
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
      "chrony" # SNTP client and server
      "avahi-daemon" # mDNS support
      "openssh-server" # Remote login
      "nginx" # Web server

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
      "ros-jazzy-micro-ros-agent"

      # Raph Rover ROS package dependencies
      "ros-jazzy-ackermann-msgs"
      "ros-jazzy-depth-image-proc"
      "ros-jazzy-depthai"
      "ros-jazzy-depthai-bridge"
      "ros-jazzy-generate-parameter-library"
      "ros-jazzy-image-proc"
      "ros-jazzy-image-transport-plugins"
      "ros-jazzy-joy-linux"
      "ros-jazzy-laser-filters"
      "ros-jazzy-robot-state-publisher"
      "ros-jazzy-rosapi"
      "ros-jazzy-rosbridge-server"
      "ros-jazzy-rplidar-ros"
      "ros-jazzy-web-video-server"
      "ros-jazzy-xacro"
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
  inherit OSName debsStage0 debsStage1 raph_common_src raph_robot_src;

  pname = "${OSName}-image";
  version = OSVersion;

  memSize = 4096;

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

  postVM = ''
    # Shrink the disk image
    LAST_SECTOR=$(${pkgs.parted}/bin/parted $diskImage -ms unit s print | tail -n +3 | cut -d: -f3 | sed 's/s//' | sort -n | tail -1)
    GPT_BACKUP_TABLE_SECTORS=34
    SECTOR_SIZE=512
    DISK_SIZE=$(( (LAST_SECTOR + GPT_BACKUP_TABLE_SECTORS) * SECTOR_SIZE ))

    ${pkgs.qemu_kvm}/bin/qemu-img resize --shrink -f raw $diskImage $DISK_SIZE
    ${pkgs.gptfdisk}/bin/sgdisk -e $diskImage
  '';
})
