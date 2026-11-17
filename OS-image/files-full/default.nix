{ stdenv }:
stdenv.mkDerivation {
  name = "files";
  src = ./.;
  phases = [
    "unpackPhase"
    "installPhase"
  ];

  installPhase = ''
    # Copy the files
    mkdir -p $out
    cp -vr etc usr $out
  '';
}
