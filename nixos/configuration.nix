# AttrSet of system.
{ subconf, pkgs, lib, ... }:

let
  inherit (lib) optionals;
  gnome = subconf.gnome or false;
in {
  imports = [
    ./disko.nix
    ./home.nix
  ];

  boot.loader = {
    systemd-boot.enable = true;
    efi.efiSysMountPoint = "/efi";
    efi.canTouchEfiVariables = true;
  };

  networking = {
    hostName = subconf.hostname;
    hostId = subconf.hostid;
    networkmanager.enable = true;
    firewall.allowedTCPPorts = [ 22 ];
    firewall.allowedUDPPorts = [ ];
  };

  time.timeZone = "Asia/Shanghai";
  i18n.defaultLocale = "zh_CN.UTF-8";

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    substituters = [ "https://mirrors.ustc.edu.cn/nix-channels/store" ];
  };

  environment = {
    # vs. variables?
    sessionVariables = {
      NIX_CRATES_INDEX = "sparse+https://mirrors.ustc.edu.cn/crates.io-index/";
      NIXOS_OZONE_WL = "1";
    };

    # For basically the user root and the desktop, won't use it much:
    systemPackages = with pkgs; [
      git
      ptyxis
      helix
    ];

    # Why not in services?
    gnome.excludePackages = [ pkgs.gnome-tour ];
  };

  services = {
    openssh = {
      enable = true;
      ports = [ 22 ];
    };

    xserver = {
      enable = gnome;
      displayManager.gdm.enable = gnome;
      desktopManager.gnome.enable = gnome;
      excludePackages = [ pkgs.xterm ];
    };

    # https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/x11/desktop-managers/gnome.md
    gnome.core-utilities.enable = false;
  };

  fonts.packages = with pkgs; optionals gnome [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    noto-fonts-emoji
    sarasa-gothic
  ];

  virtualisation = {
    containers.enable = true;
    podman = {
      enable = true;
      defaultNetwork.settings.dns_enabled = true;
    };
  };

  # TODO: system.copySystemConfiguration = true; Flake doesn't support it.
  system.stateVersion = "24.11";
}
