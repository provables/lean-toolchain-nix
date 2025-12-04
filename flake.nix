{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
    shell-utils.url = "github:waltermoreira/shell-utils";
  };
  outputs = { self, nixpkgs, flake-utils, shell-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        shell = shell-utils.myShell.${system};

        toolchain =
          leanVersion:
          let
            hashes = {
              aarch64-darwin = {
                "4.20.1" = "sha256-Ay/RV+ZsQ5blPv4fnzBHgDHhAhodISHrigaG1wUQHIg=";
                "4.21.0" = "sha256-clPmvzmNchv3wODsTVCzgHmO7LBEXMctWc7cwGbo7Z0=";
                "4.22.0" = "sha256-9YL5VKjMfK3kpGiMPlYPjdx+Rm3hr62q4lEgDaxdwaM=";
              };
              aarch64-linux = {
                "4.20.1" = "sha256-PgvfYGmO+nWqwAWNcipxtGCXX08gGI3eSfEsBcZJWCg=";
                "4.21.0" = "sha256-soZSrh2J/8J4697B0dJJ7muEKL9yq+V9mpIw5mPf1jA=";
                "4.22.0" = "sha256-6YRd5hY5lafGrPGZx2oZSWhSJHSxWzBvJoBwmyTyL9M=";
              };
              x86_64-darwin = {
                "4.20.1" = "sha256-Qlk1qljI2QVnbYCFVtV7DQf0oGCuzkdboKMJegOWRtA=";
                "4.21.0" = "";
                "4.22.0" = "";
              };
              x86_64-linux = {
                "4.20.1" = "sha256-EDlz49ECpEAYHdkihEOa5hVU27lP9g4vyNN7bfixHXw=";
                "4.21.0" = "";
                "4.22.0" = "";
              };
            };
            toolchainDownload =
              pkgs.stdenv.mkDerivation {
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
                outputHash = hashes.${system}.${leanVersion};
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
          pkgs.stdenv.mkDerivation {
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
          };
        leanDevShell = leanVersion: shell {
          name = "lean-toolchain-${leanVersion}";
          buildInputs = with pkgs; [
            (toolchain leanVersion)
            elan
            go-task
            git
          ] ++ lib.optional stdenv.isDarwin apple-sdk_14;
        };
        gitRecording = pkgs.writeShellApplication {
          name = "git";
          runtimeInputs = with pkgs; [
            git
            jq
            gnused
            coreutils
          ];
          text = ''
            GITLOG=$(realpath -s "$GITLOG")
            mkdir -p "$GITLOG"
            [ ! -s "$GITLOG/contents.json" ] && echo "{}" > "$GITLOG/contents.json"
            REPO="$(basename "$( (git rev-parse --show-toplevel || echo -n) 2>/dev/null)")"
            P="$(realpath -s --relative-to="$GITBASE" "$(pwd)")"
            A="''${*//$GITBASE/GITBASE}"
            OUT=$(echo -n "$P|$A" | md5sum | cut -f1 -d' ')
            STATUS=0
            O=$(git "$@" 2>&1 | tee) || STATUS="$?"
            echo -n "''${O//$GITBASE/GITBASE}" > "$GITLOG/$OUT"
            PREV=$(cat "$GITLOG/contents.json")
            echo "$PREV" | \
              jq --arg P "$P" --arg A "$A" --arg OUT "$OUT" --arg S "$STATUS" \
                --arg R "$REPO" \
              '.byPath."\($P)"."\($A)" = {"out": $OUT, "status": $S} | .byRepo."\($R)"."\($A)" = {"out": $OUT, "status": $S}' \
              > "$GITLOG/contents.json"
            cat "$GITLOG/$OUT"
            exit "$STATUS"
          '';
        };
        gitReplaying = pkgs.writeShellApplication {
          name = "git";
          runtimeInputs = with pkgs; [
            git
            jq
            gnused
            coreutils
          ];
          text = ''
            test -n "$GITLOG"
            test -n "$GITBASE"
            if [ -d ".git" ]; then
              REPO="$(basename "$(pwd)")"
            else
              REPO=""
            fi
            P="$(realpath -s --relative-to="$GITBASE" "$(pwd)")"
            A="''${*//$GITBASE/GITBASE}"
            CONTENT=$(jq -r --arg P "$P" --arg A "$A" --arg R "$REPO" \
              '.byRepo."\($R)"."\($A)"' \
              "$GITLOG/contents.json")
            if [ "$CONTENT" = "null" ]; then
              git "$@"
            else
              FILETOPLAY=$(echo "$CONTENT" | jq -r '.out' )
              STATUS=$(echo "$CONTENT" | jq -r '.status' )
              sed "s|GITBASE|$GITBASE|g" < "$GITLOG/$FILETOPLAY" 
              exit "$STATUS"
            fi
          '';
        };
        mathlib = leanVersion:
          let
            hashes = {
              aarch64-darwin = {
                "4.20.1" = "sha256-FKRtXZmT12ikXDBUD21HxnwGPVYuYG3CMwfiYrxL1vk=";
                "4.21.0" = "";
                "4.22.0" = "";
              };
              aarch64-linux = {
                "4.20.1" = "";
                "4.21.0" = "";
                "4.22.0" = "";
              };
              x86_64-darwin = {
                "4.20.1" = "";
                "4.21.0" = "";
                "4.22.0" = "";
              };
              x86_64-linux = {
                "4.20.1" = "sha256-lEnHqW9awz/ts6Op9kqXvbjb6pkaAP/C9HR0xr0RZEE=";
                "4.21.0" = "";
                "4.22.0" = "";
              };
            };
            lean = toolchain leanVersion;
          in
          pkgs.stdenv.mkDerivation {
            name = "mathlib-${leanVersion}";
            outputHashAlgo = "sha256";
            outputHashMode = "recursive";
            outputHash = hashes.${system}.${leanVersion};
            src = ./empty;
            buildInputs = with pkgs; [
              lean
              rsync
              curl
              gitRecording
              coreutils
              moreutils
              ripgrep
              gnused
              jq
              findutils
            ];
            nativeBuildInputs = with pkgs; [
              cacert
            ];
            phases = [ "unpackPhase" "buildPhase" ];
            buildPhase = ''
              substituteInPlace lakefile.toml lean-toolchain \
                --subst-var-by leanVersion "${leanVersion}"
              mkdir -p $out
              export HOME=$(mktemp -d)
              export GITLOG=$(pwd)/gitlog
              export GITBASE=$(pwd)
              lake exe cache get
              lake build
              for f in $(find .lake/packages -name .git -type d); do
                rm -rf $f
                mkdir -p $f
              done
              rm -rf .lake/packages/mathlib/.lake/build/bin
              echo "----- Cleaning up traces"
              for f in $(find .lake/packages -path "*.lake*.trace" -type f); do
                jq '.log[]?.message = ""' "$f" | sponge "$f"
                jq '.inputs = []' "$f" | sponge "$f"
              done
              rsync -a .lake/packages/ $out
              cp -r $GITLOG $out/.gitlog
            '';
          };
        buildLeanPackage =
          { leanVersion ? "4.20.1"
          , buildInputs ? [ ]
          , ...
          }@params:
          let
            _mathlib = mathlib leanVersion;
            _lean = toolchain leanVersion;
          in
          pkgs.stdenv.mkDerivation (params // {
            buildInputs = buildInputs ++ [ gitReplaying _lean ];
            patchPhase = ''
              mkdir -p .lake/packages
              for f in `ls ${_mathlib}/`; do ln -s ${_mathlib}/$f .lake/packages/$f; done
              export GITLOG="${_mathlib}/.gitlog"
              export GITBASE="$(pwd)"
            '';
          });
        test =
          let
            mathlib420 = mathlib "4.20.1";
            lean = toolchain "4.20.1";
          in
          pkgs.stdenv.mkDerivation {
            name = "test";
            src = ./test/foo;
            buildInputs = [
              gitReplaying
              lean
            ];
            patchPhase = ''
              mkdir -p .lake/packages
              for f in `ls ${mathlib420}/`; do ln -s ${mathlib420}/$f .lake/packages/$f; done
              export GITLOG="${mathlib420}/.gitlog"
              export GITBASE="$(pwd)"
            '';
            buildPhase = ''
              lake build
              mkdir -p $out
              cp .lake/build/lib/lean/Foo.olean $out
            '';
          };
          test2 = buildLeanPackage {
            name = "test2";
            src = ./test/foo;
            buildPhase = ''
              lake build
              mkdir -p $out
              cp .lake/build/lib/lean/Foo.olean $out
            '';
          };
      in
      {
        packages = {
          lean-toolchain-4_20 = toolchain "4.20.1";
          lean-toolchain-4_21 = toolchain "4.21.0";
          lean-toolchain-4_22 = toolchain "4.22.0";
          default = toolchain "4.22.0";
          mathlib-4_20 = mathlib "4.20.1";
          inherit test test2 gitRecording gitReplaying;
        };

        devShells = {
          lean-4_20 = leanDevShell "4.20.1";
          lean-4_21 = leanDevShell "4.21.0";
          lean-4_22 = leanDevShell "4.22.0";
          default = leanDevShell "4.22.0";
        };
      }
    );
}
