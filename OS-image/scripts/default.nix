{
  files,
  pkgs,
  stdenv,
  makeWrapper,
}:
{
  stage1 = stdenv.mkDerivation {
    name = "scripts";
    src = ./buildStage1.sh;
    nativeBuildInputs = [ makeWrapper ];
    phases = [
      "installPhase"
      "postFixup"
    ];
    installPhase = ''
      mkdir -p $out
      cp -vr $src $out/build.sh
      patchShebangs $out/build.sh
    '';
    postFixup = ''
      wrapProgram $out/build.sh \
      --set PATH "${
        with pkgs;
        lib.makeBinPath [
          coreutils
          e2fsprogs
          dosfstools
          dpkg
          gptfdisk
          util-linux
        ]
      }" \
      --set NIX_STORE_DIR ${builtins.storeDir}
    '';
  };

  stage2 = stdenv.mkDerivation {
    name = "scripts";
    src = ./buildStage2.sh;
    nativeBuildInputs = [ makeWrapper ];
    phases = [
      "installPhase"
      "postFixup"
    ];
    installPhase = ''
      mkdir -p $out
      cp -vr $src $out/build.sh
      patchShebangs $out/build.sh
    '';
    postFixup = ''
      wrapProgram $out/build.sh \
      --set PATH "${
        with pkgs;
        lib.makeBinPath [
          coreutils
          util-linux
        ]
      }" \
      --set NIX_STORE_DIR ${builtins.storeDir}
    '';
  };

  stage3 = stdenv.mkDerivation {
    name = "scripts";
    src = ./buildStage3.sh;
    nativeBuildInputs = [ makeWrapper ];
    phases = [
      "installPhase"
      "postFixup"
    ];
    installPhase = ''
      mkdir -p $out
      cp -vr $src $out/build.sh
      patchShebangs $out/build.sh
    '';
    postFixup = ''
      wrapProgram $out/build.sh \
      --set PATH "${
        with pkgs;
        lib.makeBinPath [
          coreutils
          util-linux
        ]
      }" \
      --set NIX_STORE_DIR ${builtins.storeDir}
    '';
  };

  stage4 = stdenv.mkDerivation {
    name = "scripts";
    src = ./buildStage4.sh;
    nativeBuildInputs = [ makeWrapper ];
    phases = [
      "installPhase"
      "postFixup"
    ];
    installPhase = ''
      mkdir -p $out
      cp -vr $src $out/build.sh
      patchShebangs $out/build.sh
    '';
    postFixup = ''
      wrapProgram $out/build.sh \
      --set PATH "${
        with pkgs;
        lib.makeBinPath [
          coreutils
          gnused
          systemd
          util-linux
        ]
      }" \
      --set FILES_DIR ${files} \
      --set UDEVD "${pkgs.systemd}/lib/systemd/systemd-udevd"
    '';
  };

  stageFinal = stdenv.mkDerivation {
    name = "scripts-stageFinal";
    src = ./buildStageFinal.sh;
    nativeBuildInputs = [ makeWrapper ];
    phases = [
      "installPhase"
      "postFixup"
    ];
    installPhase = ''
      mkdir -p $out
      cp -vr $src $out/build.sh
      patchShebangs $out/build.sh
    '';
    postFixup = ''
      wrapProgram $out/build.sh \
      --set PATH "${
        with pkgs;
        lib.makeBinPath [
          coreutils
          e2fsprogs
          findutils
          gawk
          gnugrep
          gnused
          parted
          util-linux
          zerofree
        ]
      }"
    '';
  };
}
