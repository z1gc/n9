# Library of N9, devices should rely on this for modular.
# TODO: Mo(re)dules, when more devices.

{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    colmena = {
      url = "github:zhaofengli/colmena";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-anywhere = {
      url = "github:nix-community/nixos-anywhere";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      colmena,
      ...
    }@args:
    let
      # Fetch all directories:
      dirs =
        dir:
        let
          contents = builtins.readDir dir;
          directories = builtins.filter ({ value, ... }: value == "directory") (
            nixpkgs.lib.attrsToList contents
          );
        in
        builtins.map ({ name, ... }: name) directories;

      colmenaHive = colmena.lib.makeHive (
        nixpkgs.lib.fold nixpkgs.lib.recursiveUpdate { } (
          builtins.map (
            dir:
            let
              inputs = args // {
                n9 = self;
                self = outputs;
              };

              # Flake like import (the "outputs" part):
              outputs = import ./mach/${dir} inputs;
            in
            (builtins.removeAttrs outputs.nixosConfigurations [ "passthru" ])
          ) (dirs ./mach)
        )
      );

      # @see nix/flake.nix
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
    in
    {
      # NixOS, Nix (For package manager only, use lib.mkNixPackager?):
      lib.nixos = import ./lib/nixos.nix args;
      lib.nixos-modules = import ./nixos args;

      # User/home level modules, with home-manager:
      lib.home = import ./lib/home.nix args;
      lib.home-modules = import ./home args;

      # Simple utils, mainly for making the code "shows" better.
      # In modules, you can refer it using `self.lib.utils`.
      lib.utils = import ./lib/utils.nix args;

      # All of the machines:
      inherit colmenaHive;

      # Compatible to nixos-anywhere or other tools (nixosSystem way):
      nixosConfigurations = colmenaHive.nodes;

      # Entry:
      apps = nixpkgs.lib.genAttrs systems (import ./lib/apps.nix args);
    };
}
