{ lib, stdenv, pkgs, shell, toolchain, ... }:
leanVersion:
shell {
  name = "lean-toolchain-${leanVersion}";
  buildInputs = with pkgs; [
    (toolchain leanVersion)
    elan
    go-task
    git
  ] ++ lib.optional stdenv.isDarwin apple-sdk_14;
}
