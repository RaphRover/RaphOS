{ lib, pkgs, vmTools, fetchurl, systemd, gptfdisk, util-linux, dosfstools
, e2fsprogs, ... }:
vmTools.makeImageFromDebDist {
  name = "RaphaOS";
  fullName = "RaphaOS";

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

  packages = [
    "base-passwd"
    "dpkg"
    "libc6-dev"
    "perl"
    "bash"
    "dash"
    "gzip"
    "bzip2"
    "tar"
    "grep"
    "mawk"
    "sed"
    "findutils"
    "curl"
    "patch"
    "locales"
    "coreutils"
    "util-linux"
    "file"
    "diffutils"
    "libc-bin"
    "bsdutils"
    "less" 

    # Needed because it provides /etc/login.defs, whose absence causes
    # the "passwd" post-installs script to fail.
    "login"
    "passwd"

    "systemd" # init system
    "init-system-helpers" # satisfy undeclared dependency on update-rc.d in udev hooks
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

  size = 8192;

  buildCommand = import ./scripts/build.nix {
    inherit lib pkgs gptfdisk util-linux dosfstools e2fsprogs systemd;
  };
}
