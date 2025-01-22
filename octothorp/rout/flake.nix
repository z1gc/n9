# https://github.com/astro/nix-openwrt-imagebuilder
# https://github.com/astro/nix-openwrt-imagebuilder/blob/main/example-x86-64.nix
# https://downloads.openwrt.org/releases/23.05.5/targets/x86/64/profiles.json

# To test on my ARM64 machine, can only built remotely:
# https://github.com/NixOS/nix/issues/2789
# nix flake show
# sudo nix build --builders "ssh-ng://byte@rout x86_64-linux" ".#packages.x86_64-linux.openwrt"

{
  inputs.n9.url = "../../ampersand";
  inputs.openwrt-imagebuilder = {
    url = "github:astro/nix-openwrt-imagebuilder";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      n9,
      openwrt-imagebuilder,
      ...
    }:
    let
      inherit (nixpkgs) lib;
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      target = "x86";
      variant = "64";
      profile = "generic";
      release = import "${openwrt-imagebuilder}/latest-release.nix";
      image = "openwrt-${release}-${target}-${variant}-${profile}";

      overrideConfigs =
        prev:
        builtins.concatStringsSep " " (
          [
            prev
            "sed -i -E -e ''"
          ]
          ++ (builtins.map ({ name, value }: "-e 's/^(CONFIG_${name}=).+$/\\1${value}/'") (
            lib.attrsToList {
              TARGET_ROOTFS_SQUASHFS = "n";
              TARGET_ROOTFS_EXT4FS = "n";
              GRUB_IMAGES = "n";
              GRUB_EFI_IMAGES = "n";
            }
          ))
          ++ [ ".config" ]
        );
    in
    {
      inherit system;

      packages.${system} = {
        # With OpenWRT packages:
        openwrt-image =
          (openwrt-imagebuilder.lib.build {
            inherit
              target
              variant
              profile
              pkgs
              ;

            # https://openwrt.org/docs/guide-user/additional-software/saving_space
            # TODO: Remove the kmod totally? It isn't much possible without
            #       hacking the openwrt/include/kernel.mk, and it headaches.
            # TODO: Replace kmodloader to a dummpy script.
            packages = [
              "curl"
              "yq"
              "dnsmasq-full"
              "ip-full"
              "luci"
              "luci-ssl"
              "luci-app-acme"
              "acme-acmesh-dnsapi"
              "luci-app-statistics"
              "collectd-mod-cpufreq"
              "collectd-mod-load"
              "collectd-mod-sensors"
              "luci-app-ttyd"

              "-dnsmasq"
              "-opkg"
              "-luci-app-opkg"
              "-dropbear"
            ];
            disabledServices = [ ];
          }).overrideAttrs
            (prev: {
              preBuild = overrideConfigs (prev.preBuild or "");
              preInstall = "rm bin/targets/${target}/${variant}/${image}-kernel.bin";
              postInstall = "cp .config $out/${image}.config";
            });

        # With configurtaions "injected":
        # openwrt = pkgs.stdenv.mkDerivation {
        #   src = self.packages.${system}.openwrt-image + "/";
        #   dontFixup = true;
        # };
      };

      nixosConfigurations = n9.lib.nixos self {
        # packages = [ self.packages.${system}.openwrt ];

        modules = with n9.lib.nixos-modules; [
          ./hardware-configuration.nix
          (disk.btrfs "/dev/nvme0n1")
          {
            boot.kernelModules = [
              "pppoe"
              "inet_diag"
            ];
            networking = {
              useDHCP = false;
              dhcpcd.enable = false;
              networkmanager.enable = lib.mkForce false;
              firewall.enable = false;
            };
          }
        ];
      };

      homeConfigurations = n9.lib.home self (n9.lib.utils.user2 "byte" ./passwd) {
        packages = [
          "tcpdump"
          "bridge-utils"
          "ethtool"
          "nftables"
        ];

        modules = with n9.lib.home-modules; [
          editor.helix
          shell.fish
          {
            home.file.".ssh/authorized_keys" =
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILb5cEj9hvj32QeXnCD5za0VLz56yBP3CiA7Kgr1tV5S byte@harm";
          }
        ];
      };
    };
}
