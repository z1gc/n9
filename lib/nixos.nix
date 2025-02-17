{
  self,
  nixpkgs,
  home-manager,
  ...
}@args: # <- Flake inputs

# Make NixOS, with disk, bootloader, networking, hostname, etc.
#
# @input that: Flake `self` of the modules.
# @input hostName: The name you're.
# @input system: The system running.
# @input modules: To nixosSystem.
# @input packages: Shortcut.
# @input deployment: Where you want to deploy?
#
# @output: AttrSet of ${hostName} of ${that}.
#
# Notice, the deployment.keys are uploaded, it means it can't survive next
# reboot if you're using the default option to upload to /run/keys.
that: hostName: system:
{
  modules,
  packages ? [ ],
  deployment ? { },
}: # <- Module arguments

let
  inherit (self.lib) utils;
  inherit (nixpkgs) lib;

  hostId = builtins.substring 63 8 (builtins.hashString "sha512" hostName);
  hasHome = that ? homeConfigurations;
  homeConfig = that.homeConfigurations.${hostName};

  subModules =
    [
      (import ../pkgs/nixpkgs.nix args)
      (
        { pkgs, ... }:
        {
          nix.settings = {
            experimental-features = [
              "nix-command"
              "flakes"
            ];
            substituters = [ "https://mirrors.ustc.edu.cn/nix-channels/store" ];
          };

          boot.loader = {
            systemd-boot.enable = true;
            efi.canTouchEfiVariables = true;
          };

          # For default networking, using NixOS's default (dhcpcd).
          networking = {
            inherit hostName hostId;
          };

          environment = {
            sessionVariables.NIX_CRATES_INDEX = "sparse+https://mirrors.ustc.edu.cn/crates.io-index/";

            systemPackages =
              with pkgs;
              [
                git
              ]
              ++ (map (utils.attrByIfStringPath pkgs) packages);
          };

          time.timeZone = "Asia/Shanghai";
          i18n.defaultLocale = "zh_CN.UTF-8";

          virtualisation = {
            containers.enable = true;
            podman = {
              enable = true;
              defaultNetwork.settings.dns_enabled = true;
            };
          };

          system.stateVersion = "25.05";

          # TODO: To other places.
          services.openssh = {
            enable = true;
            ports = [ 22 ];
            authorizedKeysFiles = [ "/etc/ssh/agent_keys.d/%u" ];
          };
          networking.firewall.allowedTCPPorts = [ 22 ];

          # Fine-gran control of which user can use PAM to authorize things.
          security.pam = {
            sshAgentAuth = {
              enable = true;
              authorizedKeysFiles = [ "/etc/ssh/agent_keys.d/%u" ];
            };
            services.sudo.sshAgentAuth = true;
          };
        }
      )

      home-manager.nixosModules.home-manager
      {
        # https://discourse.nixos.org/t/users-users-name-packages-vs-home-manager-packages/22240/2
        home-manager.useUserPackages = true;
        home-manager.useGlobalPkgs = true;
      }
    ]
    ++ (lib.optionals hasHome (
      (lib.mapAttrsToList (
        username:
        {
          user,
          group,
          config,
          ...
        }:
        # { pkgs, ... }:
        assert lib.assertMsg (username != "root") "can't manage root!";
        {
          users = {
            groups.${username} = group;
            users.${username} = user;
          };

          home-manager.users.${username} = config;
        }
      ) homeConfig)
      ++ [
        { users.users.root.hashedPassword = "!"; }
      ]
    ))
    ++ (lib.optionals (deployment ? targetUser && deployment ? targetKey) [
      (
        { nodes, pkgs, ... }:
        let
          user = deployment.targetUser;
          uid = 27007;

          allow = command: {
            inherit command;
            options = [ "SETENV" ];
          };

          # https://github.com/zhaofengli/colmena/blob/main/src/nix/host/key_uploader.template.sh
          # Restricted and checked access.
          keyUploader = pkgs.writers.writeBash "key_uploader.sh" ''
            set -euo pipefail
            eval "$(grep -E '^[[:alnum:]]+=[[:alnum:]\-_''${}/."]+$' <<< "$2")"

            case "$destination" in
              ${
                builtins.concatStringsSep "|" (
                  lib.mapAttrsToList (_: v: v.path) nodes.${hostName}.config.deployment.keys
                )
              }) ;;
              *)
                echo "-EPERM ($destination)"
                exit 1 ;;
            esac

            parent="$(dirname "$destination")"
            if [[ ! -d "$parent" ]]; then
              mkdir "$parent"
            fi

            touch "$tmp"
            chown "$user:$group" "$tmp" || true
            chmod "$permissions" "$tmp"
            cat <&0 > "$tmp"
            mv "$tmp" "$destination"
          '';

          store = "/nix/store/[a-z0-9]{32}-nixos-system-[a-zA-Z0-9.-]";
        in
        {
          # TODO: Rush seems lack of setgid cap? @see may_setgroups
          # A better solution is to hack rush to avoid changing the groups.
          security.wrappers.rush = {
            setgid = true;
            owner = "root";
            group = "root";
            source = "${pkgs.rush}/bin/rush";
          };

          users.groups.${user}.gid = uid;
          users.users.${user} = {
            isSystemUser = true;
            inherit uid;
            group = user;
            shell = "/run/wrappers/bin/rush";
            hashedPassword = "!";
          };

          environment.etc."ssh/agent_keys.d/${user}" = {
            mode = "0644";
            text = deployment.targetKey;
          };

          environment.etc."rush.rc" = {
            mode = "0644";
            text = ''
              rush 2.0

              rule upload-keys
                match $user == "${user}" && $# >= 3 && ''${-3} == "/bin/sh"
                set [-3] = "${keyUploader}"
                fall-through

              rule sudo
                match $user == "${user}" && $0 == "sudo"
                set [0] = "/run/wrappers/bin/sudo"
                # acct on
                # fork on
            '';
          };
          security.sudo.extraRules = [
            {
              users = [ user ];
              runAs = "root";
              commands = [
                (allow "${keyUploader} -c ^[[\\:print\\:]]+$")
                (allow "/run/current-system/sw/bin/nix-env --profile /nix/var/nix/profiles/system --set ^${store}$")
                (allow "^${store}/bin/switch-to-configuration$ switch")
              ];
            }
          ];

          nix.settings.trusted-users = [ user ];
        }
      )
    ])
    ++ modules;

  combined = nixpkgs.lib.recursiveUpdate {
    allowLocalDeployment = true;
    keys = lib.optionalAttrs hasHome (
      lib.fold (a: b: a.deployment.keys // b) { } (lib.attrValues homeConfig)
    );
  } (builtins.removeAttrs deployment [ "targetKey" ]);
in
{
  # For home.nix, n9 requires one-to-one configuration, can only have 1 host:
  passthru = {
    inherit hostName system;
  };
}
// {
  meta =
    let
      nodeNixpkgs = nixpkgs.legacyPackages.${system};
    in
    {
      nixpkgs = nodeNixpkgs;
      nodeNixpkgs.${hostName} = nodeNixpkgs;
    };

  "${hostName}" = {
    imports = subModules;
    deployment = combined;
  };
}
