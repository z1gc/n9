# To build and test:
# nix build --print-out-paths --no-link --no-write-lock-file ".#nixosConfigurations.evil.config.system.build.toplevel"
# Replace "evil" to other machine can test theirs'.
# For (print) debug, `builtins.trace` can help a lot, or `lib.traceVal`.
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

      hosts =
        let
          contents = lib.attrsToList (builtins.readDir ./dev);
          dirs = builtins.filter (dir: dir.value == "directory") contents;
        in builtins.map (dir: dir.name) dirs;
    in {
      nixosConfigurations = lib.genAttrs hosts (hostname:
        let
          subconf = {
            # Default values, can be overriden:
            inherit hostname;
            user = { name = "byte"; uid = 1000; };
            group = { name = "byte"; gid = 1000; };
          } // (import ./dev/${hostname});

          asterisk =
            let
              conf = ./asterisk/${hostname};
            in lib.optionals (lib.pathIsRegularFile conf) [ conf ];
        in lib.nixosSystem {
          system = subconf.system;

          # https://www.reddit.com/r/NixOS/comments/1bqzg78/comment/kx64qh1/
          specialArgs = { inherit subconf; };

          # @see nixpkgs/flake.nix::nixosSystem
          modules = [
            # thirdparty:
            ./pkgs
            disko.nixosModules.disko
            home-manager.nixosModules.home-manager

            # configuration:
            ./nixos
            subconf.toplevel
          ] ++ asterisk;
        });
    };
}
