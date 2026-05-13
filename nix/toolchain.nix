{ stdenv, pkgs, hashes, ... }:
leanVersion:
let
  toolchainDownload =
    stdenv.mkDerivation {
      name = "toolchain-${leanVersion}-download";
      buildInputs = with pkgs; [
        coreutils
        gnutar
        git
        curl
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
        export HOME=$(mktemp -d)
        mkdir -p $out
        curl https://elan.lean-lang.org/elan-init.sh -sSf > install-lean
        chmod +x install-lean
        ./install-lean -y
        source $HOME/.elan/env

        export ELAN_HOME=$(mktemp -d)

        elan toolchain install ${leanVersion}
        cd $ELAN_HOME/toolchains
        GZIP=-n tar --sort=name \
          --mtime="UTC 1970-01-01" \
          --owner=0 --group=0 --numeric-owner --format=gnu \
          -zcf $out/toolchain.tgz .
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
