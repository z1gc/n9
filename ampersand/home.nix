{
  self,
  nixpkgs,
  home-manager,
  sops-nix,
  ...
}@args:

# Making a Home Manager things.
# If nixos:
#   @input {username,uid,home,passwd}: Information about the user.
#                                    The group's info is same as the user.
#   @input modules: Imports from.
#   @input packages: Shortcut of home.packages, within the imports context.
#                    Due to this restriction, this should be array of strings.
#                    For other packages, you might need to write a module.
#   @output: AttrSet of ${username} = {uid,home,passwd,config}.
# Else (standalone homeManager):
#   @input {username,home}: Information about the user.
#   @input modules: Imports from.
#   @input packages: Shortcut of home.packages.
#   @output: What homeManagerConfiguration generates, should use `home-manager
#            switch` instead.
# Using if/else here because we want to maintain a consistency of dev's flake.
that:
{
  username,
  uid ? 1000,
  home ? "/home/${username}",
  passwd ? null,
}:
{
  packages ? [ ],
  modules ? [ ],
}:

let
  inherit (self.lib) utils;

  isNixos = that ? nixosConfigurations;
  system = that.system;

  config = {
    imports = [
      sops-nix.homeManagerModules.sops
      (
        { pkgs, ... }:
        {
          home.packages =
            with pkgs;
            [
              ripgrep
              fd
              wget
              age
              p7zip
              jq
              yq
              cached-nix-shell

              strace
              sysstat
              lm_sensors
              bcc
              bpftrace
            ]
            ++ (map (utils.attrByIfStringPath pkgs) packages);
          sops.age.keyFile = "${home}/.cache/.whats-yours-is-mine";
        }
      )
    ] ++ modules;

    home = {
      inherit username;
      homeDirectory = home;
      stateVersion = "25.05";
    };
  };
in
{
  ${username} =
    if (nixpkgs.lib.trace "isNixos? ${nixpkgs.lib.boolToString isNixos}" isNixos) then
      {
        inherit
          uid
          home
          passwd
          config
          ;
      }
    else
      home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.${system};

        modules = [
          (import ./nixpkgs.nix args)
          {
            programs.home-manager.enable = true;
          }
          config
        ];
      };
}
