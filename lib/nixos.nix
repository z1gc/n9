{
  self,
  nixpkgs,
  home-manager,
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
  inherit (nixpkgs) lib;

  nodeNixpkgs = nixpkgs.legacyPackages.${system};
  hostId = builtins.substring 63 8 (builtins.hashString "sha512" hostName);
  hasHome = that ? homeConfigurations;
  deployment = nixpkgs.lib.recursiveUpdate {
    allowLocalDeployment = true;
    keys = lib.optionalAttrs hasHome (
      lib.fold (a: b: a.deploy.keys // b) { } (lib.attrValues that.homeConfigurations)
    );
  } deploy;
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

        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
        }
      ]
      ++ (lib.optionals hasHome (
        (lib.mapAttrsToList (
          username:
          {
            uid,
            home,
            passwd,
            config,
            ...
          }:
          args:
          assert lib.assertMsg (username != "root") "can't manage root!";
          {
            users = {
              groups.${username} = {
                gid = uid;
              };

              users.${username} = {
                isNormalUser = true;
                inherit uid home;
                group = username;
                extraGroups = [ "wheel" ];
                hashedPasswordFile = passwd;
              };
            };

            home-manager.users.${username} = config;
          }
        ) that.homeConfigurations)
        ++ [
          {
            users.users.root.hashedPassword = "!";
          }
        ]
      ))
      ++ modules;
  };
}
