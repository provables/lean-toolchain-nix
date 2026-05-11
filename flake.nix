{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    simple-flake.url = "github:waltermoreira/simple-flake";
    shell-utils.url = "github:waltermoreira/shell-utils";
  };

  outputs = inputs@{ simple-flake, ... }:
    simple-flake.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      perSystem = { inputs', pkgs, system, ... }:
        let
          hashes = (import ./nix/hashes.nix).${system};
          toolchain = pkgs.callPackage ./nix/toolchain.nix { inherit hashes; };
          gitPlay = pkgs.callPackage ./nix/gitPlay.nix { };
          buildLean = pkgs.callPackage ./nix/buildLean.nix { inherit gitPlay toolchain; };
          leanDevShell = pkgs.callPackage ./nix/shell.nix {
            inherit (inputs'.shell-utils.lib) shell;
            inherit toolchain;
          };
        in
        {
          lib = {
            inherit buildLean;
          };
          packages = {
            lean-toolchain-4_28 = toolchain "4.28.0";
          };
          devShells = {
            lean-4_28 = leanDevShell "4.28.0";
          };
        };
    };
}
