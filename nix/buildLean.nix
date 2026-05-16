{ stdenv
, pkgs
, makeWrapper
, cacert
, gitPlay
, toolchain
, ...
}:

{
  deps =
    { name
    , src
    , leanVersion ? "4.28.0"
    , buildInputs ? [ ]
    , buildPhase ? ""
    , outputHash ? ""
    , ...
    }@params:
    let
      _lean = toolchain leanVersion;
    in
    stdenv.mkDerivation (params // {
      name = "${name}-deps";
      buildInputs = buildInputs ++ (with pkgs; [
        _lean
        gitPlay.record
        rsync
        curl
        gnutar
        gzip
        findutils
      ]);
      nativeBuildInputs = [ makeWrapper cacert ];
      outputHashAlgo = "sha256";
      outputHashMode = "recursive";
      inherit outputHash;
      phases = [ "unpackPhase" "buildPhase" ];
      src = builtins.path {
        path = src;
        name = "${name}-src";
        filter = path: type: baseNameOf path != ".lake";
      };
      #LEAN_CC = "${pkgs.gcc}/bin/cc -L${_lean}/lib";
      buildPhase = ''
        mkdir -p $out
        export HOME=$(mktemp -d)
        export GITLOG=$(pwd)/gitlog
        export GITBASE=$(pwd)
        ${buildPhase}
        rm -rf .lake/build
        rm -rf .lake/packages/mathlib/.lake/build/bin
        for f in $(find .lake/packages -name .git -type d); do
            rm -rf $f
            mkdir -p $f
        done
        cp -r $GITLOG $out/.gitlog
        cp lakefile.toml $out/
        cd .lake
        GZIP=-n tar --sort=name \
            --mtime="UTC 1970-01-01" \
            --owner=0 --group=0 --numeric-owner --format=gnu \
            -zcf $out/lake.tgz .
      '';
    });

  package =
    { name
    , src
    , deps ? null
    , leanVersion ? "4.28.0"
    , buildInputs ? [ ]
    , buildPhase ? ""
    , ...
    }@params:
    let
      _lean = toolchain leanVersion;
    in
    stdenv.mkDerivation (params // {
      inherit name;
      src = builtins.path {
        path = src;
        name = "${name}-src";
        filter = path: type: baseNameOf path != ".lake";
      };
      buildInputs = buildInputs ++ (with pkgs; [
        gitPlay.replay
        _lean
        gnutar
        rsync
      ]);
      #LEAN_CC = "${pkgs.gcc}/bin/cc -L${_lean}/lib";
      buildPhase = ''
        mkdir -p .lake
      '' + (if deps != null then ''
        export GITLOG=${deps}/.gitlog
        export GITBASE=$(pwd)
        tar zxf ${deps}/lake.tgz -C .lake
      '' else "") + ''
        mkdir -p $out/lib
        export HOME=$(mktemp -d)
        ${buildPhase}
        rsync -a .lake/ $out/lib
      '';
    });
}
