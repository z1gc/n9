{ self, ... }: # <- Flake inputs

# Making a Home Manager things.
#
# @input that: Flake `self` of the modules.
# @input username: The username of it.
# @input passwd: The absolute path to passwd file, in colmena.
# @input uid,home: Information about the user.
#                  The group's info is same as the user.
# @input packages: Shortcut of home.packages, within the imports context.
#                  Due to this restriction, this should be array of strings.
#                  For other packages, you might need to write a module.
# @input modules: Imports from.
# @input deploy: Additional arguments to deployer, currently supports keys.
#
# @output: AttrSet of ${username} = {uid,home,config,passwd,deploy}.
# Using if/else here because we want to maintain a consistency of dev's flake.
that: username: passwd: # <- Module arguments

{
  uid ? 1000,
  home ? "/home/${username}",
  packages ? [ ],
  modules ? [ ],
  deploy ? {
    keys = { };
  },
}: # <- NixOS or HomeManager configurations (kind of)

let
  inherit (self.lib) utils;

  config = {
    imports = [
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
        }
      )
    ] ++ modules;

    home = {
      inherit username;
      homeDirectory = home;
      stateVersion = "25.05";
    };
  };

  deployment.keys =
    # User provided:
    (builtins.mapAttrs (
      _: v:
      v
      // {
        user = username;
        group = username;
      }
    ) deploy.keys)
    # Password argument:
    // {
      "passwd-${username}" = {
        keyFile = passwd;
        permissions = "0400";
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
    passwd = "/run/keys/passwd-${username}";
    deploy = deployment;
  };
}
