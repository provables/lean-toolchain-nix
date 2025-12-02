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
          ] ++ lib.optional stdenv.isDarwin apple-sdk_14;
        };
        gitRecording = pkgs.writeShellApplication {
          name = "git";
          runtimeInputs = with pkgs; [
            git
            jq
            gnused
          ];
          text = ''
            GITLOG=$(realpath "$GITLOG")
            mkdir -p "$GITLOG"
            [ ! -s "$GITLOG/contents.json" ] && echo "{}" > "$GITLOG/contents.json"
            P="$(realpath --relative-to="$GITBASE" "$(pwd)")"
            A="''${*//$GITBASE/GITBASE}"
            OUT=$(echo -n "$P|$A" | md5sum | cut -f1 -d' ')
            STATUS=0
            O=$(git "$@" 2>&1) || STATUS="$?"
            echo "''${O//$GITBASE/GITBASE}" > "$GITLOG/$OUT"
            PREV=$(cat "$GITLOG/contents.json")
            echo "$PREV" | \
              jq --arg P "$P" --arg A "$A" --arg OUT "$OUT" --arg S "$STATUS" \
              '."\($P)"."\($A)" = {"out": $OUT, "status": $S}' > "$GITLOG/contents.json"
            cat "$GITLOG/$OUT"
            exit "$STATUS"
          '';
        };
        mathlib = leanVersion:
          let
            hashes = {
              aarch64-darwin = {
                "4.20.1" = "sha256-M7I8sJhjAN0rB6g9QeEb7zfoC18COhjT27yYnubRXcU=";
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
                "4.20.1" = "";
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
              git config --global user.name "No Name"
              git config --global user.email "<no@email.org>"
              lake exe cache get
              lake build
              mv $GITLOG $out
              # cd .lake/packages
              # rsync -a . $out
            '';
          };
        test = pkgs.fetchgit {
          name = "test";
          url = "https://github.com/waltermoreira/nginx-test.git";
          leaveDotGit = true;
          rev = "104f8596ad7d13305ce8d4cd894d4f9a59bc0aea";
          hash = "sha256-EEG/6zfF9PsZ4cF/72Thnp6AwMoAGDp6PlYgLC0HQRA=";
        };
        mathlibHashes = {
          aesop = {
            rev = "ddfca7829bf8aa4083cdf9633935dddbb28b7b2a";
            hash = "sha256-4j2VuLmlGCmscGpb6hrDwBFUwjBOtUchGSzCQGpSQv8=";
            url = "https://github.com/leanprover-community/aesop";
          };
          batteries = {
            rev = "7a0d63fbf8fd350e891868a06d9927efa545ac1e";
            hash = "sha256-LyiG6rc9kNn8K0/2mDaD8RtOsTwK9vYQHiffNXNi/VU=";
            url = "https://github.com/leanprover-community/batteries";
          };
          Cli = {
            rev = "f9e25dcbed001489c53bceeb1f1d50bbaf7451d4";
            hash = "sha256-6VZQ4v4bTCuDy0JZNIM0ckw4b5gyHvQmhT/4Keoq0xE=";
            url = "https://github.com/leanprover/lean4-cli";
          };
          importGraph = {
            rev = "a11bcb5238149ae5d8a0aa5e2f8eddf8a3a9b27d";
            hash = "sha256-tOMps125FAUTZxZyzPt3VVQpg3f5IPjabTYq8JLcr3o=";
            url = "https://github.com/leanprover-community/import-graph";
          };
          LeanSearchClient = {
            rev = "6c62474116f525d2814f0157bb468bf3a4f9f120";
            hash = "sha256-HLw4aMWH5UHqhbmc42fi7/jxlSEcqs0oE99ANjwfmog=";
            url = "https://github.com/leanprover-community/LeanSearchClient";
          };
          mathlib = {
            rev = "5c0c94b3f563ed756b48b9439788c53b0d56a897";
            hash = "sha256-joY0g+ZXhRP6buFL3X/37qMtZ7ep6N/e3p3VTLdYTtY=";
            url = "https://github.com/leanprover-community/mathlib4";
          };
          plausible = {
            rev = "2ac43674e92a695e96caac19f4002b25434636da";
            hash = "sha256-5NY4ewpgno+O28xvhHbB2jjX45uvQtisSd8zQx0hR58=";
            url = "https://github.com/leanprover-community/plausible";
          };
          proofwidgets = {
            rev = "21e6a0522cd2ae6cf88e9da99a1dd010408ab306";
            hash = "sha256-lGCDKbVSh0W/MLFW9k5WrQP/pk5lDP2dwOI25x9La24=";
            url = "https://github.com/leanprover-community/ProofWidgets4";
          };
          Qq = {
            rev = "2865ea099ab1dd8d6fc93381d77a4ac87a85527a";
            hash = "sha256-hIdwZC0HGNeyRs9KPszvLAUZcRTuza8OGITxMtt9//w=";
            url = "https://github.com/leanprover-community/quote4";
          };
        };
        mathlibRepos = pkgs.linkFarm "mathlibRepos" (
          builtins.attrValues
            (builtins.mapAttrs
              (name: value: {
                inherit name;
                path = pkgs.fetchgit {
                  inherit name;
                  url = value.url;
                  leaveDotGit = true;
                  rev = value.rev;
                  hash = value.hash;
                };
              })
              mathlibHashes
            )
        );
      in
      {
        packages = {
          lean-toolchain-4_20 = toolchain "4.20.1";
          lean-toolchain-4_21 = toolchain "4.21.0";
          lean-toolchain-4_22 = toolchain "4.22.0";
          default = toolchain "4.22.0";
          mathlib-4_20 = mathlib "4.20.1";
          inherit test mathlibRepos gitRecording;
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
