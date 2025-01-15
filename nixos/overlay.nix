# package.override: Replace the argument (of stdenv.mkDerivation)
# package.overrideAttrs: Replace the difinition
# e.g. { arg1, arg2, ... }: stdenv.mkDerivation { src = ... }
# TODO: What finalAttrs means?

{ pkgs, ... }:

{
  nixpkgs = {
    config.allowUnfree = true;

    overlays = [
      (self: super: {
        helix = super.helix.overrideAttrs (prev: {
          patches = (prev.patches or []) ++ [
            (pkgs.fetchpatch {
              url = "https://github.com/z1gc/helix/commit/16bff48d998d01d87f41821451b852eb2a8cf627.patch";
              hash = "sha256-JBhz0X7/cdRDZ4inasPvxs+xlktH2+cK0190PDxPygE=";
            })
          ];
        });

        openssh = super.openssh.overrideAttrs (prev: {
          patches = (prev.patches or []) ++ [
            (pkgs.fetchpatch {
              url = "https://github.com/z1gc/openssh-portable/commit/b3320c50cb0c74bcc7f0dade450c1660fd09b241.patch";
              hash = "sha256-kiR/1Jz4h4z+fIW9ePgNjEXq0j9kHILPi9UD4JruV7M=";
            })
          ];
        });

        brave = super.brave.override (prev: {
          commandLineArgs = (prev.commandLineArgs or "") + ''
            --sync-url=https://brave-sync.pteno.cn/v2
          '';
        });
      })
    ];
  };
}
