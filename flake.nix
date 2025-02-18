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
      importArgs = file: import file args;

      disk =
        args: type: device:
        (importArgs ./nixos/disk) { inherit type device; };

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

      # To compat with nixosSystem, may used in the future.
      nixosConfigurations = builtins.removeAttrs (nixpkgs.lib.fold nixpkgs.lib.recursiveUpdate { } (
        builtins.map (
          dir:
          let
            # Flake like import:
            conf = import ./mach/${dir} (
              args
              // {
                n9 = self;
                self = conf;
              }
            );
          in
          conf.nixosConfigurations
        ) (dirs ./mach)
      )) [ "passthru" ];

      mkPatches =
        patches: pkg: pkgs:
        pkg.overrideAttrs (prev: {
          patches = (prev.patches or [ ]) ++ (builtins.map pkgs.fetchpatch patches);
        });
      mkPatch = patch: mkPatches [ patch ];

      # @see nix/flake.nix
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
    in
    {
      # NixOS, Nix (For package manager only, use lib.mkNixPackager?):
      # TODO: With no hard code?
      lib.nixos = importArgs ./lib/nixos.nix;
      lib.nixos-modules = {
        disk.zfs = disk args "zfs";
        disk.btrfs = disk args "btrfs";
        desktop.gnome = importArgs ./nixos/desktop/gnome.nix;
        miscell.sshd = importArgs ./nixos/miscell/sshd.nix;
      };

      # User/home level modules, with home-manager:
      lib.home = importArgs ./lib/home.nix;
      lib.home-modules = {
        desktop.pop-shell = importArgs ./home/desktop/pop-shell.nix;
        editor.helix = importArgs ./home/editor/helix.nix;
        shell.fish = importArgs ./home/shell/fish.nix;
        v12n.boxes = importArgs ./home/v12n/boxes.nix;
        miscell.git = importArgs ./home/miscell/git.nix;
      };

      # Simple utils, mainly for making the code "shows" better.
      # In modules, you can refer it using `self.lib.utils`.
      lib.utils = {
        # A little bit clean way to add patches, and a single patch:
        inherit mkPatches mkPatch;

        # Turn "xyz" to pkgs.xyz (only if "xyz" is string) helper:
        attrByIfStringPath =
          set: maybeStringPath:
          if (builtins.typeOf maybeStringPath == "string") then
            nixpkgs.lib.attrsets.attrByPath (nixpkgs.lib.strings.splitString "." maybeStringPath) null set
          else
            maybeStringPath;

        # Setup SSH keys:
        sshKey =
          path:
          let
            key = builtins.baseNameOf path;
          in
          {
            # ssh-keygen -f [private] -y > [public]
            ${key} = {
              keyFile = path;
              permissions = "0400";
              destDir = "@HOME@/.ssh";
            };
          };
      };

      # All of the machines:
      colmenaHive = colmena.lib.makeHive nixosConfigurations;

      # Entry:
      apps = nixpkgs.lib.genAttrs systems (importArgs ./lib/apps.nix);
    };
}
