{ files, imageBuilder, pkgs }:
let
  mkScript = imageBuilder.mkScript;
in
{
  stage1 = mkScript {
    name = "scripts-stage1";
    src = ./buildStage1.sh;
    packages = with pkgs; [
      coreutils
      e2fsprogs
      dosfstools
      dpkg
      gptfdisk
      util-linux
    ];
    environment = { NIX_STORE_DIR = builtins.storeDir; };
  };

  stage2 = mkScript {
    name = "scripts-stage2";
    src = imageBuilder.stageScripts.installDebs;
    packages = with pkgs; [ coreutils util-linux ];
    environment = {
      NIX_STORE_DIR = builtins.storeDir;
      BOOT_MOUNT = "/boot/efi";
      CLEAN_CHROOT_ENV = "false";
    };
  };

  stage3 = mkScript {
    name = "scripts-stage3";
    src = imageBuilder.stageScripts.installDebs;
    packages = with pkgs; [ coreutils util-linux ];
    environment = {
      NIX_STORE_DIR = builtins.storeDir;
      BOOT_MOUNT = "/boot/efi";
      CLEAN_CHROOT_ENV = "false";
    };
  };

  stage4 = mkScript {
    name = "scripts-stage4";
    src = ./buildStage4.sh;
    packages = with pkgs; [ coreutils gnused systemd util-linux ];
    environment = {
      FILES_DIR = files;
      UDEVD = "${pkgs.systemd}/lib/systemd/systemd-udevd";
    };
  };

  stageFinal = mkScript {
    name = "scripts-stageFinal";
    src = imageBuilder.stageScripts.finalizeImage;
    packages = with pkgs; [
      coreutils
      e2fsprogs
      findutils
      gawk
      gnugrep
      gnused
      parted
      util-linux
      zerofree
    ];
    environment = { BOOT_MOUNT = "/boot/efi"; };
  };
}
