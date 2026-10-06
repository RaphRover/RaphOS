{
  files,
  imageBuilder,
  pkgs,
}:
{
  stage1 = imageBuilder.mkScript {
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
  };

  stage2 = imageBuilder.mkInstallDebsScript {
    name = "scripts-stage2";
    environment = {
      BOOT_MOUNT = "/boot/efi";
    };
  };

  stage3 = imageBuilder.mkInstallDebsScript {
    name = "scripts-stage3";
    environment = {
      BOOT_MOUNT = "/boot/efi";
    };
  };

  stage4 = imageBuilder.mkScript {
    name = "scripts-stage4";
    src = ./buildStage4.sh;
    packages = with pkgs; [
      coreutils
      gnused
      systemd
      util-linux
    ];
    environment = {
      FILES_DIR = files;
      UDEVD = "${pkgs.systemd}/lib/systemd/systemd-udevd";
    };
  };

  stageFinal = imageBuilder.mkFinalizeImageScript {
    name = "scripts-stageFinal";
    environment = {
      BOOT_MOUNT = "/boot/efi";
    };
  };
}
