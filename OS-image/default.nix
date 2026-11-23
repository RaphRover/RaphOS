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

  files-lite = pkgs.callPackage ./files-lite { };

  files-full = pkgs.callPackage ./files-full { };

  scripts = pkgs.callPackage ./scripts { inherit files-lite files-full imageBuilder; };

  packageLists =
    let
      noble-updates-stamp = "20261119T120000Z";
      ros2-stamp = "2026-11-16";
      fictionlab-stamp = "2026-11-23";
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
            sha256 = "sha256-M9hCEsPuHkLZQquLKdUebr8K3k7/2kKtzc7DPWWAjuc=";
          }
        );
        urlPrefix = "http://snapshot.ubuntu.com/ubuntu/${noble-updates-stamp}";
      }
      {
        name = "noble-updates-universe";
        packagesFile = (
          fetchurl {
            url = "http://snapshot.ubuntu.com/ubuntu/${noble-updates-stamp}/dists/noble-updates/universe/binary-amd64/Packages.xz";
            sha256 = "sha256-erTe4skOs0F3S+cXGivRVNyEsARl43j6ukCgJU4EF8I=";
          }
        );
        urlPrefix = "http://snapshot.ubuntu.com/ubuntu/${noble-updates-stamp}";
      }
      {
        name = "ros2";
        packagesFile = (
          fetchurl {
            url = "http://snapshots.ros.org/jazzy/${ros2-stamp}/ubuntu/dists/noble/main/binary-amd64/Packages.bz2";
            sha256 = "sha256-8JU838nT8HQf5RkDCzr/0ST8Sid6rg8msATq/sTXfn8=";
          }
        );
        urlPrefix = "http://snapshots.ros.org/jazzy/${ros2-stamp}/ubuntu";
      }
      {
        name = "fictionlab";
        packagesFile = (
          fetchurl {
            url = "https://archive.fictionlab.pl/dists/noble/snapshots/${fictionlab-stamp}/main/binary-amd64/Packages.gz";
            sha256 = "sha256-Ns4jsA3LxCZq1PEmgOWlpIrU3nYJ2NYeH4+LyvI50us=";
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

      "---"

      # STAGE 4 - Desktop packages
      "xorg" # X11 server
      "xserver-xorg-video-fbdev" # X11 framebuffer driver
      "lxqt" # Desktop environment
      "openbox" # Window manager
      "lightdm" # Display manager
      "lightdm-gtk-greeter" # Greeter for lightdm
      "accountsservice" # User account management
      "gvfs" # Trash support
      "lubuntu-artwork" # LXQt theme
      "papirus-icon-theme" # LXQt icon theme
      "kde-style-breeze" # LXQt color scheme
      "breeze-cursor-theme" # LXQt cursor theme
      "firefox-esr" # Web browser
      "tigervnc-scraping-server" # VNC server

      "ros-jazzy-desktop"
      "ros-jazzy-raph-desktop"
    ];
  }) { inherit fetchurl; };

  exportStage = stageNr: builtins.elemAt debsClosure stageNr;

  debsStage0 = exportStage 0;
  debsStage1 = exportStage 1;
  debsStage2 = exportStage 2;
  debsStage3 = exportStage 3;
  debsStage4 = exportStage 4;

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
        env = {
          debsStage = debsStage2;
        };
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
      {
        name = "stage5";
        outputName = "OSStage5Image";
        script = scripts.stage5;
        env = { debsStage = debsStage4; };
        debInputs = [ debsStage4 ];
      }
      {
        name = "stage6";
        outputName = "OSStage6Image";
        script = scripts.stage6;
      }
    ];
  };
in
rec {
  OSStage1Image = imageStages.OSStage1Image;
  OSStage2Image = imageStages.OSStage2Image;
  OSStage3Image = imageStages.OSStage3Image;
  OSStage4Image = imageStages.OSStage4Image;
  OSStage5Image = imageStages.OSStage5Image;
  OSStage6Image = imageStages.OSStage6Image;

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

  OSFullImage = imageBuilder.mkQcow2ImageStage {
    pname = "${OSName}-full-image";
    version = OSVersion;
    inherit memSize;
    previousImage = OSStage6Image;
    script = scripts.stageFinal;
    logOutput = true;
    env = {
      inherit OSName OSVersion;
      OSVariant = "full";
    };
  };

  OSFullRawImage = imageBuilder.mkRawImage {
    image = OSFullImage;
    osName = OSName;
    osVersion = OSVersion;
    variant = "full";
    filename = "OS.img";
    repairGpt = true;
  };
}
