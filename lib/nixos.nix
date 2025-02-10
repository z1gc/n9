{
  self,
  nixpkgs,
  home-manager,
  sops-nix,
  colmena,
  ...
}@args: # <- Flake inputs

# Make NixOS, with disk, bootloader, networking, hostname, etc.
# Switched from `nixosSystem` to `colmenaHive`, for my own flaver (the colmena
# has both remote and local deployment, which is quite nice).
# @input that: Flake `self` of the modules.
# @input modules: To nixosSystem.
# @input packages: Shortcut.
# @input deploy: Where you want to deploy?
# @output: AttrSet of ${hostName} of ${that}.
# TODO: Revert using `nixosSystem` when there's no deployment?
that: hostName: system: # <- Module arguments

{
  modules,
  packages ? [ ],
  deploy ? { },
}: # <- NixOS `nixosSystem {}` (Hmm, not really)

let
  inherit (self.lib) utils;

  nodeNixpkgs = nixpkgs.legacyPackages.${system};
  hostId = builtins.substring 63 8 (builtins.hashString "sha512" hostName);
  hasHome = that ? homeConfigurations;
  deployment = {
    allowLocalDeployment = true;
  } // deploy;
in
colmena.lib.makeHive {
  meta = {
    # TODO: Multiple calls? Flavor of mine is to deploy each machine
    # individually, instead of "bunch" (have no that much of machines, huh).
    nixpkgs = nodeNixpkgs;
    nodeNixpkgs.${hostName} = nodeNixpkgs;
  };

  ${hostName} = {
    inherit deployment;

    imports =
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
                  gnumake
                  git
                  sops
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
            networking = {
              firewall.allowedTCPPorts = [ 22 ];
              firewall.allowedUDPPorts = [ ];
            };

            services.openssh = {
              enable = true;
              ports = [ 22 ];
            };
          }
        )

        sops-nix.nixosModules.sops
        {
          sops.age.keyFile = "/root/.cache/.whats-yours-is-mine";
        }

        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
        }
      ]
      ++ (nixpkgs.lib.optionals hasHome (
        nixpkgs.lib.mapAttrsToList (
          # TODO: Assert username is not root:
          username:
          {
            uid,
            home,
            config,
          }:
          args: {
            users = {
              groups.${username} = {
                gid = uid;
              };

              users.${username} = {
                isNormalUser = true;
                inherit uid home;
                group = username;
                extraGroups = [ "wheel" ];
              };
            };

            home-manager.users.${username} = config;
          }
        ) that.homeConfigurations
      ))
      ++ modules;
  };
}
