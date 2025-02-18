{ self, nixpkgs, ... }: # <- Flake inputs

# Making a Home Manager things.
#
# @input that: Flake `self` of the modules.
# @input username: The username of it.
# @input passwd: The absolute path to passwd file, in colmena.
# @input uid,home,groups: Information about the user.
#                         Group's name and gid is same as the username and uid.
# @input authorizedKeys: SSH keys for authorizing.
# @input agentKeys: For passwordless SSH sudo, it's a little risky, but it is
#                   needed for colmena.
# @input packages: Shortcut of home.packages, within the imports context.
#                  Due to this restriction, this should be array of strings.
#                  For other packages, you might need to write a module.
# @input modules: Imports from.
# @input deployment: Additional arguments to deployer, currently supports keys.
#
# @output: AttrSet of {modules,deployment}.
# Using if/else here because we want to maintain a consistency of dev's flake.
that: username: passwd: # <- Module arguments

{
  uid ? 1000,
  home ? "/home/${username}",
  authorizedKeys ? [ ],
  agentKeys ? [ ],
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

          services.ssh-agent.enable = true;
          programs.ssh = {
            enable = true;
            addKeysToAgent = "9h";
            forwardAgent = true;
          };
        }
      )
    ] ++ (builtins.map (m: m.__home__ or m) modules);

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
assert lib.assertMsg (username != "root") "can't manage root!";
{
  # TODO: Way to assert unique username?
  ${that.nixosConfigurations.passthru.hostName}.${username} = {
    modules =
      (builtins.filter (m: m != null) (
        builtins.map (
          m:
          if m ? __nixos__ then
            if builtins.isFunction m.__nixos__ && (builtins.functionArgs m.__nixos__) ? username then
              m.__nixos__ { inherit username; }
            else
              m.__nixos__
          else
            null
        ) modules
      ))
      ++ [
        {
          users.groups.${username}.gid = uid;

          users.users.${username} = {
            isNormalUser = true;
            inherit uid home;
            group = username;
            extraGroups = [ "wheel" ] ++ groups;
            hashedPasswordFile = "/run/keys/passwd-${username}";
            openssh.authorizedKeys.keys = authorizedKeys;
          };

          home-manager.users.${username} = config;
        }
      ]
      ++ lib.optionals (builtins.length agentKeys != 0) [
        {
          environment.etc."ssh/agent_keys.d/${username}" = {
            text = builtins.concatStringsSep "\n" agentKeys;
            mode = "0644";
          };
        }
      ]
      ++ lib.optionals (builtins.length authorizedKeys != 0 || builtins.length agentKeys != 0) [
        # FIXME: want a different port?
        (self.lib.nixos-modules.sshd { })
      ];

    deployment = combined;
  };
}
