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
                "4.20.1" = "";
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
      in
      {
        packages = {
          lean-toolchain-4_20 = toolchain "4.20.1";
          lean-toolchain-4_21 = toolchain "4.21.0";
          lean-toolchain-4_22 = toolchain "4.22.0";
          default = toolchain "4.22.0";
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
