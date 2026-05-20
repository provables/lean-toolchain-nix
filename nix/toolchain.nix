{ lib, stdenv, makeWrapper, pkgs, hashes, ... }:
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
        export ELAN_HOME=$(mktemp -d)
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
    makeWrapper
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
    tar zxf ${toolchainDownload}/toolchain.tgz
    ln -s leanprover--lean4---v${leanVersion}/* .
  '';
  doDist = true;
  distPhase = ''
    for f in `find $out/bin/ -type f`; do
      echo "LD is $(cat $NIX_CC/nix-support/dynamic-linker)"
      patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" "$f" || true
    done
    wrapProgram $out/bin/clang \
      --append-flags "-Wl,-dynamic-linker=$(cat $NIX_CC/nix-support/dynamic-linker)"
    # ln -s ${pkgs.gcc}/bin/cc $out/bin/cc
    # wrapProgram $out/bin/cc --add-flags \
    #   "--sysroot $out -L $out/lib -L $out/lib/glibc \
    #   -lc -lc_nonshared -Wl,--as-needed -l:ld.so -Wl,--no-as-needed \
    #   -lpthread_nonshared -Wl,--as-needed -Wl,-Bstatic -lgmp -lunwind -luv \
    #   -Wl,-Bdynamic -Wl,--no-as-needed -fuse-ld=lld"
  '';
}
