{
  self,
  nixpkgs,
  home-manager,
  sops-nix,
  ...
}: # <- Flake inputs

# Make NixOS, with disk, bootloader, networking, hostname, etc.
# TODO: mkIf style configurations? It loses flexibility.
# @input that: Flake `self` of the modules.
# @input args.{system,modules}: To nixosSystem.
# @output: AttrSet of ${hostName} of ${that}.
that: # <- Module arguments

{ system, ... }@args: # <- NixOS `nixosSystem {}` (Hmm, not really)
let
  utils = self.lib.utils;
  hostName = builtins.unsafeDiscardStringContext (builtins.baseNameOf that);
  hostId = builtins.substring 63 8 (builtins.hashString "sha512" hostName);
in
{
  ${hostName} =
    nixpkgs.lib.nixosSystem {
      inherit system;

      modules =
        [
          (
            { pkgs, ... }:
            {
              nixpkgs.overlays = [
                (self: super: {
                  helix = utils.mkPatch {
                    url = "https://github.com/plxty/helix/commit/16bff48d998d01d87f41821451b852eb2a8cf627.patch";
                    hash = "sha256-JBhz0X7/cdRDZ4inasPvxs+xlktH2+cK0190PDxPygE=";
                  } super.helix pkgs;

                  openssh = utils.mkPatch {
                    url = "https://github.com/plxty/openssh-portable/commit/b3320c50cb0c74bcc7f0dade450c1660fd09b241.patch";
                    hash = "sha256-kiR/1Jz4h4z+fIW9ePgNjEXq0j9kHILPi9UD4JruV7M=";
                  } super.openssh pkgs;
                })
              ];

              nixpkgs.config.allowUnfree = true;

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
                  helix
                  age
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
        ++ (nixpkgs.lib.optionals (that ? homeConfigurations) (
          nixpkgs.lib.mapAttrsToList (
            # TODO: Assert username is not root:
            username:
            {
              uid,
              home,
              passwd,
              config,
            }:
            args: {
              sops.secrets = nixpkgs.lib.optionalAttrs (passwd != null) {
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
        ++ args.modules;
    }
    // builtins.removeAttrs args [ "modules" ];
}
