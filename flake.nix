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

        leanVersion = "4.22.0";

        toolchain =
          let
            hashes = {
              aarch64-darwin = {
                "4.21.0" = "sha256-clPmvzmNchv3wODsTVCzgHmO7LBEXMctWc7cwGbo7Z0=";
                "4.22.0" = "sha256-9YL5VKjMfK3kpGiMPlYPjdx+Rm3hr62q4lEgDaxdwaM=";
              };
              aarch64-linux = {
                "4.21.0" = "sha256-soZSrh2J/8J4697B0dJJ7muEKL9yq+V9mpIw5mPf1jA=";
                "4.22.0" = "sha256-6YRd5hY5lafGrPGZx2oZSWhSJHSxWzBvJoBwmyTyL9M=";
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
      in
      {
        packages.default = toolchain;

        devShell = shell {
          name = "lean-toolchain-${leanVersion}";
          buildInputs = with pkgs; [
            elan
            toolchain
            go-task
          ] ++ lib.optional stdenv.isDarwin apple-sdk_14;
        };
      }
    );
}
