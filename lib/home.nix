{ self, nixpkgs, ... }: # <- Flake inputs

# Making a Home Manager things.
#
# @input that: Flake `self` of the modules.
# @input username: The username of it.
# @input passwd: The absolute path to passwd file, in colmena.
# @input uid,home,groups: Information about the user.
#                         Group's name and gid is same as the username and uid.
# @input packages: Shortcut of home.packages, within the imports context.
#                  Due to this restriction, this should be array of strings.
#                  For other packages, you might need to write a module.
# @input modules: Imports from.
# @input deployment: Additional arguments to deployer, currently supports keys.
#
# @output: AttrSet of ${username} = {uid,home,config,passwd,deployment}.
# Using if/else here because we want to maintain a consistency of dev's flake.
that: username: passwd: # <- Module arguments

{
  uid ? 1000,
  home ? "/home/${username}",
  groups ? [ ],
  packages ? [ ],
  modules ? [ ],
  deployment ? {
    keys = { };
  },
}: # <- NixOS or HomeManager configurations (kind of)

let
  inherit (nixpkgs) lib;
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

  combined.keys =
    # User provided:
    (builtins.mapAttrs (
      _: v:
      v
      // lib.optionalAttrs (lib.strings.hasPrefix "@HOME@" (v.destDir or "")) {
        destDir = home + (lib.strings.removePrefix "@HOME@" v.destDir);
      }
      // {
        user = username;
        group = username;
        uploadAt = "post-activation"; # After user and home created.
      }
    ) deployment.keys)
    # Password argument:
    // {
      "passwd-${username}" = {
        keyFile = passwd;
        permissions = "0400";
      };
    };
in
{
  ${that.colmenaHive.passthru.hostName}.${username} = {
    inherit
      uid
      home
      groups
      config
      ;
    passwd = "/run/keys/passwd-${username}";
    deployment = combined;
  };
}
