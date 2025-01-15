# To build and test:
# nix build --print-out-paths --no-link --no-write-lock-file ".#nixosConfigurations.evil.config.system.build.toplevel"
# Replace "evil" to other machine can test theirs'.
# For (print) debug, `builtins.trace` can help a lot.
# P.S. Remember to stage files to git, in order the flake can find them.

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

  outputs = { nixpkgs, disko, home-manager, ... }:
    let
      lib = nixpkgs.lib;

      # TODO: Stick to current hostname only?
      hosts =
        let
          contents = lib.attrsToList (builtins.readDir ./.);
          dirs = builtins.filter (dir: dir.value == "directory") contents;
        in builtins.map (dir: dir.name) dirs;
    in {
      nixosConfigurations = lib.genAttrs hosts (hostname: lib.nixosSystem {
        # https://www.reddit.com/r/NixOS/comments/1bqzg78/comment/kx64qh1/
        specialArgs.subconf = { inherit hostname; } //
          (import ./${hostname}/configuration.nix);

        # @see nixpkgs/flake.nix::nixosSystem
        modules = [
          disko.nixosModules.disko
          ./${hostname}/hardware-configuration.nix
          ./overlay.nix
          home-manager.nixosModules.home-manager
          # TODO: Cleanup the code, just for a note here.
          # { home-manager.extraSpecialArgs = specialArgs; }
          # ({ pkgs, ... }@args: # without @ pattern it will throw an error, why?
          #   # https://ayats.org/blog/dont-use-import
          #   let
          #     subconf = { inherit hostname; } //
          #       (import ./${hostname}/configuration.nix args);
          #   in import ./configuration.nix (args // { inherit subconf; }))
          ./configuration.nix
        ];
      });
    };
}
