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
      helix = utils.mkPatch {
        url = "https://github.com/plxty/helix/commit/16bff48d998d01d87f41821451b852eb2a8cf627.patch";
        hash = "sha256-JBhz0X7/cdRDZ4inasPvxs+xlktH2+cK0190PDxPygE=";
      } super.helix pkgs;

      openssh = utils.mkPatch {
        url = "https://github.com/plxty/openssh-portable/commit/b3320c50cb0c74bcc7f0dade450c1660fd09b241.patch";
        hash = "sha256-kiR/1Jz4h4z+fIW9ePgNjEXq0j9kHILPi9UD4JruV7M=";
      } super.openssh pkgs;

      ibus-engines = super.ibus-engines // {
        # We can have a override chain! Hooray!
        rime =
          (utils.mkPatch {
            url = "https://github.com/plxty/ibus-rime/commit/d5baa3f648b409403bff87dddaf291c937de0d33.patch";
            hash = "sha256-VtgBImxvrVJGEfAvEW4rFDLghNKaxPNvrTsnEwPVakE=";
          } super.ibus-engines.rime pkgs).override
            (prev: {
              rimeDataPkgs = [ (pkgs.callPackage ./pkgs/rime-ice.nix { }) ];
            });
      };

      librime = utils.mkPatch {
        url = "https://github.com/plxty/librime/commit/c550986e57d82fe14166ca8169129607fa71a64f.patch";
        hash = "sha256-9jLSf17MBg4tHQ9cPZG4SN7uD1yOdGe/zfJrXfoZneE=";
      } super.librime pkgs;

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
