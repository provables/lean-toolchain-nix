{ stdenv, pkgs, hashes, ... }:
leanVersion:
let
  toolchainDownload =
    stdenv.mkDerivation {
      name = "toolchain-${leanVersion}-download";
      buildInputs = with pkgs; [
        elan
        coreutils
        gnutar
      ];
      nativeBuildInputs = with pkgs; [
        cacert
      ];
      outputHashAlgo = "sha256";
      outputHashMode = "recursive";
      outputHash = hashes.${leanVersion};
      src = builtins.path {
        path = ./.;
        name = "toolchain-download-src";
        filter = path: type: false;
      };
      dontFixup = true;
      dontPatchShebangs = true;
      buildPhase = ''
        mkdir -p $out/elan
        export ELAN_HOME=$out/elan
        export HOME=$(mktemp -d)
        elan toolchain install ${leanVersion}
        rm -rf $out/elan/{tmp,known-projects}
        cd $out/elan/toolchains
        GZIP=-n tar --sort=name \
          --mtime="UTC 1970-01-01" \
          --owner=0 --group=0 --numeric-owner --format=gnu \
          -zcf $out/toolchain.tgz .
        rm -rf $out/elan
      '';
      phases = [ "buildPhase" ];
    };
in
stdenv.mkDerivation {
  name = "toolchain-${leanVersion}";
  buildInputs = with pkgs; [
    elan
    toolchainDownload
  ];
  src = builtins.path {
    path = ./.;
    name = "toolchain-src";
    filter = path: type: false;
  };
  buildPhase = ''
    mkdir -p $out
    cd $out
    tar zxf ${toolchainDownload}/toolchain.tgz
    ln -s leanprover--lean4---v${leanVersion}/* .
  '';
}
