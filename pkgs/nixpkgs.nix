{ self, ... }: # <- Flake inputs

# TODO: Change name to common? For both nixos and home manager.
# No argument. <- Module arguments

{ pkgs, ... }: # <- NixOS or HomeManager `imports = []`

let
  inherit (self.lib) utils;
in
{
  nixpkgs.overlays = [
    (self: super: {
      helix = utils.patch super.helix ../patches/helix-taste.patch;
      openssh = utils.patch super.openssh ../patches/openssh-plainpass.patch;
      ibus-engines = super.ibus-engines // {
        rime = (utils.patch super.ibus-engines.rime ../patches/ibus-rime-temp-ascii.patch).override {
          rimeDataPkgs = [ (pkgs.callPackage ./rime-ice.nix { }) ];
        };
      };
      librime = utils.patch super.librime ../patches/librime-temp-ascii.patch;
      ppp = utils.patch super.ppp ../patches/ppp-run-resolv.patch;

      brave = super.brave.override (prev: {
        commandLineArgs = builtins.concatStringsSep " " [
          (prev.commandLineArgs or "")
          "--wayland-text-input-version=3"
          "--sync-url=https://brave-sync.pteno.cn/v2"
        ];
      });
    })
  ];

  nixpkgs.config.allowUnfree = true;
}
