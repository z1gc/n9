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
# @input secrets: The key you want to hide.
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
  secrets ? { },
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
            systemPackages = map (utils.attrByIfStringPath pkgs) packages;
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
        }
      )

      home-manager.nixosModules.home-manager
      {
        # https://discourse.nixos.org/t/users-users-name-packages-vs-home-manager-packages/22240/2
        home-manager.useUserPackages = true;
        home-manager.useGlobalPkgs = true;
      }
    ]
    ++ (lib.optionals (deployment ? nixKey) [
      # nix key generate-secret --key-name dotfiles.rockwolf.eu-X > .nix-key
      # cat .nix-key | nix key convert-secret-to-public
      { nix.settings.trusted-public-keys = [ deployment.nixKey ]; }
    ])
    ++ (lib.optionals hasHome (
      (lib.flatten (lib.mapAttrsToList (_: v: v.modules) homeConfig))
      ++ [ { users.users.root.hashedPassword = "!"; } ]
    ))
    ++ modules;
in
{
  # TODO: Way to assert one-to-one configuration?
  passthru = {
    inherit hostName;
  };

  meta =
    let
      nodeNixpkgs = nixpkgs.legacyPackages.${system};
    in
    {
      nixpkgs = { inherit lib; }; # doesn't matter
      nodeNixpkgs.${hostName} = nodeNixpkgs;
    };

  "${hostName}" = {
    imports = subModules;
    deployment =
      {
        allowLocalDeployment = true;
        keys = lib.optionalAttrs hasHome (
          lib.fold (a: b: a.secrets // b) secrets (lib.attrValues homeConfig)
        );
      }
      // (builtins.removeAttrs deployment [
        "keys"
        "nixKey"
      ]);
  };
}
