{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, disko, ... }:
    let
      lib = nixpkgs.lib;
      hosts =
        let
          contents = lib.attrsToList (builtins.readDir ./.);
          dirs = builtins.filter (dir: dir.value == "directory") contents;
        in builtins.map (dir: dir.name) dirs;
    in {
    nixosConfigurations = lib.genAttrs hosts (host: lib.nixosSystem {
      # @see nixpkgs/flake.nix::nixosSystem
      modules = [
        disko.nixosModules.disko
        ./${host}/hardware-configuration.nix
        ({ pkgs, ... }@args: # without @ pattern it will throw an error, why?
          let
            subconf = import ./${host}/configuration.nix args;
          in
            import ./configuration.nix
            (args // { inherit host subconf; }))
      ];
    });
  };
}
