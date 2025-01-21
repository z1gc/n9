{ self, ... }: # <- Flake inputs

# Making a GNOME Desktop.
# No arguments. <- Module arguments

{ pkgs, ... }: # <- Nix `imports = []`
let
  utils = self.lib.utils;
in
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

  environment = {
    sessionVariables.NIXOS_OZONE_WL = "1";

    systemPackages = with pkgs; [
      wl-clipboard
      brave
      ptyxis

      # TODO: dconf for extensions?
      gnomeExtensions.pop-shell
      gnomeExtensions.customize-ibus
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

  nixpkgs.overlays = [
    (self: super: {
      ibus-engines = super.ibus-engines // {
        # We can have a override chain! Hooray!
        rime =
          (utils.mkPatch {
            url = "https://github.com/z1gc/ibus-rime/commit/d5baa3f648b409403bff87dddaf291c937de0d33.patch";
            hash = "sha256-VtgBImxvrVJGEfAvEW4rFDLghNKaxPNvrTsnEwPVakE=";
          } super.ibus-engines.rime pkgs).override
            (prev: {
              rimeDataPkgs = [ (pkgs.callPackage ../pkgs/rime-ice.nix { }) ];
            });
      };

      librime = utils.mkPatch {
        url = "https://github.com/z1gc/librime/commit/c550986e57d82fe14166ca8169129607fa71a64f.patch";
        hash = "sha256-9jLSf17MBg4tHQ9cPZG4SN7uD1yOdGe/zfJrXfoZneE=";
      } super.librime pkgs;

      brave = super.brave.override (prev: {
        commandLineArgs =
          (prev.commandLineArgs or "")
          + " "
          + builtins.concatStringsSep " " [
            "--wayland-text-input-version=3"
            "--sync-url=https://brave-sync.pteno.cn/v2"
          ];
      });
    })
  ];
}
