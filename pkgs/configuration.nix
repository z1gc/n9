# package.override: Replace the argument (of stdenv.mkDerivation)
# package.overrideAttrs: Replace the difinition
# e.g. { arg1, arg2, ... }: stdenv.mkDerivation { src = ... }
# TODO: What finalAttrs means?

{ pkgs, ... }:

let
  linuxKernelWSL2 = pkgs.callPackage ./linuxKernelWSL2.nix {};
  rime-ice = pkgs.callPackage ./rime-ice.nix {};

  mkPatches = patches: prev: {
    patches = (prev.patches or []) ++ (map (p: pkgs.fetchpatch p) patches);
  };
in {
  nixpkgs = {
    config.allowUnfree = true;

    overlays = [
      (self: super: {
        helix = super.helix.overrideAttrs (mkPatches [{
          url = "https://github.com/z1gc/helix/commit/16bff48d998d01d87f41821451b852eb2a8cf627.patch";
          hash = "sha256-JBhz0X7/cdRDZ4inasPvxs+xlktH2+cK0190PDxPygE=";
        }]);

        openssh = super.openssh.overrideAttrs (mkPatches [{
          url = "https://github.com/z1gc/openssh-portable/commit/b3320c50cb0c74bcc7f0dade450c1660fd09b241.patch";
          hash = "sha256-kiR/1Jz4h4z+fIW9ePgNjEXq0j9kHILPi9UD4JruV7M=";
        }]);

        librime = super.librime.overrideAttrs (mkPatches [{
          url = "https://github.com/z1gc/librime/commit/c550986e57d82fe14166ca8169129607fa71a64f.patch";
          hash = "sha256-9jLSf17MBg4tHQ9cPZG4SN7uD1yOdGe/zfJrXfoZneE=";
        }]);

        # Seems like attr `x.y` in overlay will erase all other nested attrs?
        ibus-engines = super.ibus-engines // {
          # We can have a override chain! Hooray!
          rime = (super.ibus-engines.rime.overrideAttrs (mkPatches [{
            url = "https://github.com/z1gc/ibus-rime/commit/d5baa3f648b409403bff87dddaf291c937de0d33.patch";
            hash = "sha256-VtgBImxvrVJGEfAvEW4rFDLghNKaxPNvrTsnEwPVakE=";
          }])).override (prev: {
            rimeDataPkgs = [ rime-ice ];
          });
        };

        brave = super.brave.override (prev: {
          commandLineArgs = (prev.commandLineArgs or "") + ''
            --sync-url=https://brave-sync.pteno.cn/v2
          '';
        });

        linuxKernelWSL2 = pkgs.linuxPackagesFor linuxKernelWSL2;
      })
    ];
  };
}
