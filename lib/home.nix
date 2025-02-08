{
  self,
  nixpkgs,
  home-manager,
  sops-nix,
  ...
}@args: # <- Flake inputs

# Making a Home Manager things.
# @input username: The username of it.
#
# If nixos:
#   @input uid,home: Information about the user.
#                    The group's info is same as the user.
#   @input modules: Imports from.
#   @input packages: Shortcut of home.packages, within the imports context.
#                    Due to this restriction, this should be array of strings.
#                    For other packages, you might need to write a module.
#   @output: AttrSet of ${username} = {uid,home,config}.
# Else (standalone homeManager):
#   @input home: Information about the user.
#   @input modules: Imports from.
#   @input packages: Shortcut of home.packages.
#   @output: What homeManagerConfiguration generates, should use `home-manager
#            switch` instead.
# Using if/else here because we want to maintain a consistency of dev's flake.
that: username: # <- Module arguments

{
  uid ? 1000,
  home ? "/home/${username}",
  packages ? [ ],
  modules ? [ ],
}: # <- NixOS or HomeManager configurations (kind of)

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
              bat
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
          config
          ;
      }
    else
      home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.${system};

        modules = [
          (import ../pkgs/nixpkgs.nix args)
          {
            programs.home-manager.enable = true;
          }
          config
        ];
      };
}
