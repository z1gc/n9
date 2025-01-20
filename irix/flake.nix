# Library of N9, IR(N)IX.
# Devices should rely on this for modular.
# TODO: Mo(re)dules, when more devices.

{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { ... }@args: {
      # NixOS, Nix (For package manager only, use lib.mkNixPackager?):
      # TODO: With no hard code?
      lib.mkNixosSystem = import ./mkNixosSystem.nix args;

      # System level modules, may for NixOS only:
      lib.modules = {
        mkDisk = import ./mkDisk.nix args;
        mkGnome = import ./mkGnome.nix args;
        mkHomeManager = import ./mkHomeManager.nix args;
      };

      # User/home level modules, with home-manager:
      lib.home-modules = {
        mkHelix = import ./mkHelix.nix args;
        mkFish = import ./mkFish.nix args;
      };
    } // args;  # Should we?
}
