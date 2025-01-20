{ nixpkgs, ... }:  # <- Flake inputs

# Make NixOS, with disk, bootloader, networking, hostname, etc.
# TODO: mkIf style configurations? It loses flexibility.
# @input dir: To obtain the hostname with a relative simple way.
# @input sys: Passed to nixosSystem, then eval-config.
dir:  # <- Module arguments

sys:  # <- NixOS `nixosSystem {}` (Hmm, not really)
let
  hostName = builtins.baseNameOf dir;
  hostId = builtins.substring 63 8 (builtins.hashString "sha512" hostName);
in {
  nixosConfigurations.${hostName} = nixpkgs.lib.nixosSystem {
    modules = [
      ({ pkgs, ... }: {
        boot.loader = {
          systemd-boot.enable = true;
          efi.efiSysMountPoint = "/efi";
          efi.canTouchEfiVariables = true;
        };

        networking = {
          inherit hostName hostId;
          networkmanager.enable = true;
        };

        environment = {
          sessionVariables.NIX_CRATES_INDEX =
            "sparse+https://mirrors.ustc.edu.cn/crates.io-index/";

          systemPackages = with pkgs; [
            gnumake
            git
            helix
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

        nixpkgs.overlays = [(self: super: {
          helix = super.helix.overrideAttrs (prev: {
            patches = (prev.patches or []) ++ [(pkgs.fetchpatch {
              url = "https://github.com/z1gc/helix/commit/16bff48d998d01d87f41821451b852eb2a8cf627.patch";
              hash = "sha256-JBhz0X7/cdRDZ4inasPvxs+xlktH2+cK0190PDxPygE=";
            })];
          });
        })];

        system.stateVersion = "25.05";
      })

      # TODO: Move to mkNixPackager?
      ({ ... }: {
        nix.settings = {
          experimental-features = [ "nix-command" "flakes" ];
          substituters = [ "https://mirrors.ustc.edu.cn/nix-channels/store" ];
        };

        nixpkgs.config.allowUnfree = true;
      })

      # TODO: Move to mkSsh?
      ({ pkgs, ... }: {
        networking = {
          firewall.allowedTCPPorts = [ 22 ];
          firewall.allowedUDPPorts = [ ];
        };

        services.openssh = {
          enable = true;
          ports = [ 22 ];
        };

        nixpkgs.overlays = [(self: super: {
          openssh = super.openssh.overrideAttrs (prev: {
            patches = (prev.patches or []) ++ [(pkgs.fetchpatch {
              url = "https://github.com/z1gc/openssh-portable/commit/b3320c50cb0c74bcc7f0dade450c1660fd09b241.patch";
              hash = "sha256-kiR/1Jz4h4z+fIW9ePgNjEXq0j9kHILPi9UD4JruV7M=";
            })];
          });
        })];
      })
    ] ++ sys.modules;
  } // builtins.removeAttrs sys [ "modules" ];
}
