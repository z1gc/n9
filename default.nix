{
  system ? builtins.currentSystem,
  pkgs ? import <nixpkgs> { inherit system; }
}:

let
  callPackage = pkgs.lib.callPackageWith (pkgs // self);
  self = {
    comtrya = callPackage ./pkgs/comtrya.nix {};
  };
in
  self
