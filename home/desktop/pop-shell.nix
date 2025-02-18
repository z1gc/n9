{ self, ... }: # <- Flake inputs

# Making a Pop shell, a big extension for GNOME.
# No arguments. <- Module arguments

{
  # TODO: Nobody uses the desktop.gnome, why not remove?
  __nixos__ = _: self.lib.nixos-modules.desktop.gnome;

  __home__ =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [ pop-launcher ];

      # TODO: dconf
      programs.gnome-shell = {
        enable = true;
        extensions = [
          { package = pkgs.gnomeExtensions.pop-shell; }
          { package = pkgs.gnomeExtensions.customize-ibus; }
        ];
      };
    };
}
