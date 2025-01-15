# AttrSet of system.
# Notice, the `//` operator only works with one level (and doesn't recurse),
# for all attrs to be merged the `lib.recursiveUpdate` must be used!

{ subconf, pkgs, lib, ... }:

let
  arm64 = subconf.system == "aarch64-linux";
  hyperv = subconf.hyperv or false;
  gnome = subconf.gnome or false;
in lib.recursiveUpdate {
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

    # For basically the other user and the desktop, don't use it too much:
    systemPackages = with pkgs; [
      git
      helix
    ] ++ lib.optionals gnome [
      brave
      ptyxis
    ];

    # Why not in services?
    gnome.excludePackages = [ pkgs.gnome-tour ];
  };

  time.timeZone = "Asia/Shanghai";
  i18n = {
    defaultLocale = "zh_CN.UTF-8";

    # TODO: Rime-ice?
    inputMethod = lib.optionalAttrs gnome {
      enable = true;
      type = "ibus";
      ibus.engine = with pkgs.ibus-ibus-engines; [ rime ];
    };
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

  fonts.packages = with pkgs; lib.optionals gnome [
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

(lib.optionalAttrs (arm64 && hyperv) {
  boot.kernelPackages = pkgs.wsl2Kernel;

  virtualisation.hypervGuest = {
    enable = true;
    videoMode = "1280x720";
  };
})
