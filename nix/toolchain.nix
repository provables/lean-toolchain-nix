{ lib, stdenv, pkgs, hashes, ... }:
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
        echo "HOME: $HOME"
        export ELAN_HOME=$(mktemp -d)
        echo "ELAN_HOME: $ELAN_HOME"
        mkdir -p $out

        curl https://elan.lean-lang.org/elan-init.sh -sSf > install-lean
        chmod +x install-lean
        ./install-lean -y
        source $ELAN_HOME/env

        elan toolchain install ${leanVersion}
        cd $ELAN_HOME/toolchains
        GZIP=-n tar --sort=name \
          --mtime="UTC 1970-01-01" \
          --owner=0 --group=0 --numeric-owner --format=gnu \
          -zcf $out/toolchain.tgz .
        echo "Finished gzip"
      '';
      phases = [ "buildPhase" ];
    };
  libPath = lib.makeLibraryPath [ stdenv.cc.cc.lib pkgs.glibc pkgs.libllvm pkgs.zlib pkgs.libunwind ];
in
stdenv.mkDerivation {
  name = "toolchain-${leanVersion}";
  buildInputs = with pkgs; [
    toolchainDownload
    findutils
  ];
  src = builtins.path {
    path = ./.;
    name = "toolchain-src";
    filter = path: type: false;
  };
  buildPhase = ''
    mkdir -p $out
    cd $out
    echo "about to untar from ${toolchainDownload}"
    tar zxf ${toolchainDownload}/toolchain.tgz
    echo "untarred"
    ln -s leanprover--lean4---v${leanVersion}/* .
    echo "linked"
  '';
  doDist = true;
  distPhase = ''
    for f in `find $out/bin/`; do
      patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" "$f" || true
    done
    # for f in `find $out/lib/lean/ -name \*.so`; do
    #   patchelf --set-rpath "${libPath}:\$ORIGIN/..:\$ORIGIN" "$f" || true
    #   patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" "$f" || true
    # done
  '';
}
