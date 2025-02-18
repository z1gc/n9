# <- Flake inputs

# Making a GNOME Desktop.
# No arguments. <- Module arguments

{ pkgs, ... }: # <- Nix `imports = []`
{
  services = {
    xserver = {
      enable = true;
      displayManager.gdm.enable = true;
      desktopManager.gnome.enable = true;
      excludePackages = [ pkgs.xterm ];
    };

    # @see nixpkgs/nixos/modules/services/x11/desktop-managers/gnome.md
    gnome.core-utilities.enable = false;
  };

  # Gnome requires, @see nixpkgs/nixos/modules/services/x11/desktop-managers/gnome.nix
  # It can be safely eliminated, just keep here for a note.
  networking.networkmanager.enable = true;

  environment = {
    sessionVariables.NIXOS_OZONE_WL = "1";

    systemPackages = with pkgs; [
      wl-clipboard
      brave
      ptyxis
      nautilus
      gnome-tweaks
      dconf-editor
    ];

    # Why not in services?
    gnome.excludePackages = with pkgs; [
      gnome-tour
      gnome-shell-extensions
    ];
  };

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    noto-fonts-emoji
    sarasa-gothic
  ];

  i18n.inputMethod = {
    enable = true;
    type = "ibus";
    ibus.engines = with pkgs.ibus-engines; [
      rime
      libpinyin
    ];
  };
}
