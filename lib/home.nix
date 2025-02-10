{ self, sops-nix, ... }: # <- Flake inputs

# Making a Home Manager things.
#
# @input that: Flake `self` of the modules.
# @input username: The username of it.
# @input uid,home: Information about the user.
#                  The group's info is same as the user.
# @input modules: Imports from.
# @input packages: Shortcut of home.packages, within the imports context.
#                  Due to this restriction, this should be array of strings.
#                  For other packages, you might need to write a module.
# @output: AttrSet of ${username} = {uid,home,config}.
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
  ${username} = {
    inherit
      uid
      home
      config
      ;
  };
}
