# refs:
# https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/rust/fetch-cargo-tarball/default.nix

{
  lib,
  fetchFromGitHub,
  rustPlatform,
}:

# To rebuild: rm result && nix-collect-garbage
# Then build: nix-build --check . -A comtrya
# TODO: better way of rebuilding? These steps will re-copy the dependencies.
# You might want to `export NIX_CRATES_INDEX=<mirror_of_crates_io>` first.
rustPlatform.buildRustPackage rec {
  pname = "comtrya";
  version = "cdf55de48c4629a72a6fa2f5de622c2887d04115";

  # have to comment out the hash if the repo is updated (version unchanged):
  src = fetchFromGitHub {
    owner = "z1gc";
    repo = "${pname}";
    rev = version;
    hash = "sha256-yEtQbMRttO5tKjwlaTUEtXyGg8ul1Q5gM4vfXX03qik=";
  };

  cargoHash = "sha256-ak2HnBpsuzq04uwOTDBTO8KRjajsLfyfY10SdrUX4qY=";
  doCheck = false;

  meta = with lib; {
    description = "Configuration Management for Localhost / dotfiles";
    mainProgram = "comtrya";
    homepage = "https://github.com/comtrya/comtrya";
    license = licenses.mit;
  };
}
