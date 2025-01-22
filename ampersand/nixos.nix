{
  nixpkgs,
  home-manager,
  sops-nix,
  ...
}@args: # <- Flake inputs

# Make NixOS, with disk, bootloader, networking, hostname, etc.
# TODO: mkIf style configurations? It loses flexibility.
# @input that: Flake `self` of the modules.
# @input {modules}: To nixosSystem.
# @output: AttrSet of ${hostName} of ${that}.
that: # <- Module arguments

{ modules }: # <- NixOS `nixosSystem {}` (Hmm, not really)

let
  inherit (nixpkgs) lib;
  hostName = builtins.unsafeDiscardStringContext (builtins.baseNameOf that);
  hostId = builtins.substring 63 8 (builtins.hashString "sha512" hostName);
  hasHome = that ? homeConfigurations;
in
{
  ${hostName} = lib.nixosSystem {
    inherit (that) system;

    modules =
      [
        (import ./nixpkgs.nix args)
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

            networking = {
              inherit hostName hostId;
              networkmanager.enable = true;
            };

            environment = {
              sessionVariables.NIX_CRATES_INDEX = "sparse+https://mirrors.ustc.edu.cn/crates.io-index/";

              systemPackages = with pkgs; [
                gnumake
                git
                sops
              ];
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
      ++ (lib.optionals (lib.trace "hasHome? ${lib.boolToString hasHome}" hasHome) (
        lib.mapAttrsToList (
          # TODO: Assert username is not root:
          username:
          {
            uid,
            home,
            passwd,
            config,
          }:
          args: {
            sops.secrets = lib.optionalAttrs (passwd != null) {
              "login/${username}" = {
                # sops --age "$(awk '$2 == "public" {print $NF}' <key>)" -e <file>
                neededForUsers = true;
                format = "binary";
                sopsFile = passwd;
              };
            };

            users = {
              groups.${username} = {
                gid = uid;
              };

              users.${username} = {
                isNormalUser = true;
                inherit uid home;
                group = username;
                extraGroups = [ "wheel" ];
                hashedPasswordFile =
                  if (passwd != null) then args.config.sops.secrets."login/${username}".path else null;
              };
            };

            home-manager.users.${username} = config;
          }
        ) that.homeConfigurations
      ))
      ++ modules;
  };
}
