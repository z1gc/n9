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
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    colmena = {
      url = "github:zhaofengli/colmena";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, ... }@args:
    let
      importArgs = file: import file args;

      disk =
        args: type: device:
        (importArgs ./nixos/disk) { inherit type device; };
    in
    {
      # NixOS, Nix (For package manager only, use lib.mkNixPackager?):
      # TODO: With no hard code?
      lib.nixos = importArgs ./lib/nixos.nix;
      lib.nixos-modules = {
        disk.zfs = disk args "zfs";
        disk.btrfs = disk args "btrfs";
        desktop.gnome = importArgs ./nixos/desktop/gnome.nix;
      };

      # User/home level modules, with home-manager:
      lib.home = importArgs ./lib/home.nix;
      lib.home-modules = {
        editor.helix = importArgs ./home/editor/helix.nix;
        shell.fish = importArgs ./home/shell/fish.nix;
        secret.ssh-key = importArgs ./home/secret/ssh-key.nix;
      };

      # Simple utils, mainly for making the code "shows" better.
      # In modules, you can refer it using `self.lib.utils`.
      lib.utils = rec {
        # A little bit clean way to add patches, and a single patch:
        mkPatches =
          patches: pkg: pkgs:
          pkg.overrideAttrs (prev: {
            patches = (prev.patches or [ ]) ++ (builtins.map pkgs.fetchpatch patches);
          });
        mkPatch = patch: mkPatches [ patch ];

        # Turn "xyz" to pkgs.xyz (only if "xyz" is string) helper:
        attrByIfStringPath =
          set: maybeStringPath:
          if (builtins.typeOf maybeStringPath == "string") then
            nixpkgs.lib.attrsets.attrByPath (nixpkgs.lib.strings.splitString "." maybeStringPath) null set
          else
            maybeStringPath;

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

        # Oneliner sops binary:
        sopsBinary = sopsFile: {
          inherit sopsFile;
          format = "binary";
        };
      };
    };
}
