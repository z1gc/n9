# package.override: Replace the argument (of stdenv.mkDerivation)
# package.overrideAttrs: Replace the difinition
# e.g. { arg1, arg2, ... }: stdenv.mkDerivation { src = ... }
# TODO: What finalAttrs means?

{ pkgs, lib, ... }:

let
  # refs:
  # https://github.com/starside/Nix-On-Hyper-V-Gen-2-X-Elite/blob/main/iso_wsl.nix
  # https://github.com/NixOS/nixpkgs/blob/master/pkgs/os-specific/linux/kernel/linux-rt-6.6.nix
  # https://github.com/NixOS/nixpkgs/blob/master/pkgs/top-level/linux-kernels.nix
  wsl2KernelPackage =
    let
      version = "6.6.36.6";
      branch = lib.versions.majorMinor version;
    in { buildLinux, fetchurl, ... }@args:
      pkgs.callPackage (buildLinux (args // {
        inherit version;
        modDirVersion = version;

        src = fetchurl {
          url = "https://github.com/microsoft/WSL2-Linux-Kernel/archive/refs/tags/linux-msft-wsl-${version}.tar.gz";
          hash = "sha256-N9eu8BGtD/J1bj5ksMKWeTw6e74dtRd7WSmg5/wEmVs=";
        };

        # @see nixpkgs/nixos/modules/system/boot/kernel.nix
        structuredExtraConfig = with lib.kernel; {
          CONFIG_HYPERV_VSOCKETS = yes;
          CONFIG_PCI_HYPERV = yes;
          CONFIG_PCI_HYPERV_INTERFACE = yes;
          CONFIG_HYPERV_STORAGE = yes;
          CONFIG_HYPERV_NET = yes;
          CONFIG_HYPERV_KEYBOARD = yes;
          CONFIG_FB_HYPERV = module;
          CONFIG_HID_HYPERV_MOUSE = module;
          CONFIG_HYPERV = yes;
          CONFIG_HYPERV_TIMER = yes;
          CONFIG_HYPERV_UTILS = yes;
          CONFIG_HYPERV_BALLOON = yes;
        };

        extraMeta = {
          inherit branch;
        };
      })) {};
in {
  nixpkgs = {
    config.allowUnfree = true;

    overlays = [
      (self: super: {
        helix = super.helix.overrideAttrs (prev: {
          patches = (prev.patches or []) ++ [
            (pkgs.fetchpatch {
              url = "https://github.com/z1gc/helix/commit/16bff48d998d01d87f41821451b852eb2a8cf627.patch";
              hash = "sha256-JBhz0X7/cdRDZ4inasPvxs+xlktH2+cK0190PDxPygE=";
            })
          ];
        });

        openssh = super.openssh.overrideAttrs (prev: {
          patches = (prev.patches or []) ++ [
            (pkgs.fetchpatch {
              url = "https://github.com/z1gc/openssh-portable/commit/b3320c50cb0c74bcc7f0dade450c1660fd09b241.patch";
              hash = "sha256-kiR/1Jz4h4z+fIW9ePgNjEXq0j9kHILPi9UD4JruV7M=";
            })
          ];
        });

        brave = super.brave.override (prev: {
          commandLineArgs = (prev.commandLineArgs or "") + ''
            --sync-url=https://brave-sync.pteno.cn/v2
          '';
        });

        wsl2Kernel = pkgs.linuxPackagesFor wsl2KernelPackage;
      })
    ];
  };
}
