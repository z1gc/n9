# refs:
# https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/rust/fetch-cargo-tarball/default.nix
# Don't install, remains as a template.

{
  lib,
  fetchFromGitHub,
  rustPlatform,
}:

# To rebuild: rm result && nix-collect-garbage && nix-build . -A miniya
# (better in the nixos/nix container)
# TODO: better way of rebuilding? These steps will re-copy the dependencies.
rustPlatform.buildRustPackage rec {
  pname = "miniya";
  version = "73e25160cadfdb76dc870519da581c614073e83a";

  # have to comment out the hash if the repo is updated (version unchanged):
  src = fetchFromGitHub {
    owner = "z1gc";
    repo = "${pname}";
    rev = version;
    hash = "sha256-tsNc+oMGCRk+Xqh2gJsu+Vy8Zm8kPTN1a0tJWPLVaeI=";
  };

  # filling with `lib.fakeHash` first, then re-run to get the correct hash:
  cargoHash = "sha256-B+/V0GWYflo+IANOIQRewnIrOH7NpRh9eBhv6X3S9sI=";
  cargoBuildFlags = [ "--bin" "miniya" ];
  doCheck = false;

  meta = with lib; {
    description = "Configuration Management for Localhost / dotfiles";
    mainProgram = "miniya";
    homepage = "https://github.com/z1gc/miniya";
    license = licenses.mit;
  };
}
