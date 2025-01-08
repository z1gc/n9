# Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
# https://nix.dev/manual/nix/latest/language/operators
# https://noogle.dev/f/lib/optional

{ pkgs, lib, ... }:

let
  homeManagerChannel =
    fetchTarball
      "https://github.com/nix-community/home-manager/archive/master.tar.gz";

  # This is a lamba, or maybe the `{ attrs }` in `{ arg }: { attrs }` is a
  # syntax suger for lambda? It inputs arg and outputs attrs.
  # The `{}` is a "destructor" of attrs, eq ts `let { lib, pkgs } = attrs`,
  # which `attrs = { lib: "some_lib", pkgs: "some_pkgs" }`.
  tryImport = attrs: nix: args:
    if (builtins.pathExists nix) then
      attrs // import nix args
    else
      {};
in
{
  imports =
    [
      "${homeManagerChannel}/nixos"
      # nixos-generate-config --show-hardware-config
      ./hardware-configuration.nix
      # {% if vars.hyperv and vars.arm64 %}
      ./kernel-harm.nix
      # {% endif %}
    ];

  nix.settings.substituters =
    [ "https://mirror.sjtu.edu.cn/nix-channels/store" ];

  nixpkgs = import ./snippet/overlay.nix { inherit pkgs; };

  environment.variables = {
    NIX_CRATES_INDEX = "sparse+https://mirrors.ustc.edu.cn/crates.io-index/";
  };

  # https://nixos.wiki/wiki/Btrfs
  fileSystems = {
    "/".options = [ "compress=zstd" ];
    "/home".options = [ "compress=zstd" ];
    "/nix".options = [ "compress=zstd" "noatime" ];
  };

  # systemd-boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.efiSysMountPoint = "/efi";
  boot.loader.efi.canTouchEfiVariables = true;

  # Network:
  networking.hostName = "{{ vars.machine }}";
  # networking.wireless.enable = true;
  networking.networkmanager.enable = true;

  # Locale:
  time.timeZone = "Asia/Shanghai";
  i18n.defaultLocale = "zh_CN.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };

  # Enable the X11 windowing system.
  # services.xserver.enable = true;

  # Configure keymap in X11
  # services.xserver.xkb.layout = "us";
  # services.xserver.xkb.options = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  # hardware.pulseaudio.enable = true;
  # OR
  # services.pipewire = {
  #   enable = true;
  #   pulse.enable = true;
  # };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.libinput.enable = true;

  # genAttrs [ "ffi" ] (what: { fyi = "ptr" };)
  # => ffi.fyi = "ptr"
  users.groups = lib.genAttrs [ "{{ vars.group }}" ] (group: {
    gid = lib.strings.toInt "{{ vars.gid }}";
  });

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users = lib.genAttrs [ "{{ vars.user }}" ] (user: {
    isNormalUser = true;
    uid = lib.strings.toInt "{{ vars.uid }}";
    group = "{{ vars.group }}";
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    packages = [ ]; # Have no idea what should place.
  });

  # List packages installed in system profile. To search: nix search wget
  environment.systemPackages = with pkgs; [
    zoxide
    git
    nixd
    ripgrep
    fd
    fzf

    # Penguin!
    n9.miniya
  ];

  home-manager.users = lib.genAttrs [ "{{ vars.user }}" ] (user: {
    # No need to worry, as well:
    home.stateVersion = "24.11";
    programs = {
      fish = { enable = true; } // import ./snippet/fish.nix { inherit pkgs; };
      bash = { enable = true; } // import ./snippet/bash.nix {};
      helix = {
        enable = true; defaultEditor = true; package = pkgs.unstable.helix;
      } // import ./snippet/helix.nix {};
      git = { enable = true; } // import ./snippet/git.nix {};
      ssh = tryImport { enable = true; } ./snippet/ssh.nix {};
    };
  });

  networking.firewall.allowedTCPPorts = [ ] ++
    # {% if vars.sshd %}
    [ 22 ]
    # {% endif %}
  ;
  networking.firewall.allowedUDPPorts = [ ];

  # {% if vars.sshd %}
  services.openssh.enable = true;
  # {% endif %}

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  system.copySystemConfiguration = true;

  # No need to worry:
  system.stateVersion = "24.11";
}
