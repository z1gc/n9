# refs:
# https://github.com/starside/Nix-On-Hyper-V-Gen-2-X-Elite/blob/main/iso_wsl.nix
# https://github.com/NixOS/nixpkgs/blob/master/pkgs/os-specific/linux/kernel/linux-rt-6.6.nix
# https://github.com/NixOS/nixpkgs/blob/master/pkgs/top-level/linux-kernels.nix

{ lib, buildLinux, fetchurl, ...}@args:

let
  version = "6.6.36.6";
  branch = lib.versions.majorMinor version;
in buildLinux (args // {
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
})
