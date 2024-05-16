{ lib, pkgs }:
let inherit (pkgs) buildPackages runCommand;
in {
  debClosureGenerator = { name, packagesLists, urlPrefix, packages }:

    runCommand "${name}.nix" {
      nativeBuildInputs = [ buildPackages.perl buildPackages.dpkg ];
    } ''
      for i in ${toString packagesLists}; do
        echo "adding $i..."
        case $i in
          *.xz | *.lzma)
            xz -d < $i >> ./Packages
            ;;
          *.bz2)
            bunzip2 < $i >> ./Packages
            ;;
          *.gz)
            gzip -dc < $i >> ./Packages
            ;;
        esac
      done

      perl -w ${./deb-closure.pl} \
        ./Packages ${urlPrefix} ${toString packages} > $out
    '';
}
