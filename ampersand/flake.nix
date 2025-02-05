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
  };

  outputs =
    { nixpkgs, ... }@args:
    let
      # TODO: Modular!
      disk =
        args: type: device:
        (import ./disk args) { inherit type device; };
    in
    {
      # NixOS, Nix (For package manager only, use lib.mkNixPackager?):
      # TODO: With no hard code?
      lib.nixos = import ./nixos.nix args;
      lib.nixos-modules = {
        disk.zfs = disk args "zfs";
        disk.btrfs = disk args "btrfs";
        desktop.gnome = import ./desktop/gnome.nix args;
      };

      # User/home level modules, with home-manager:
      lib.home = import ./home.nix args;
      lib.home-modules = {
        editor.helix = import ./editor/helix.nix args;
        shell.fish = import ./shell/fish.nix args;
        secret.ssh-key = import ./secret/ssh-key.nix args;
      };

      # Simple utils, mainly for making the code "shows" better.
      # In modules, you can refer it using `self.lib.utils`.
      lib.utils = rec {
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

        # Oneliner sops binary:
        sopsBinary = sopsFile: {
          inherit sopsFile;
          format = "binary";
        };

        # 2 for argument numbers, huh.
        user2 = username: passwd: { inherit username passwd; };
      };
    };
}
