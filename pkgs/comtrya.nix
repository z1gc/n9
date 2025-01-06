# refs:
# https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/rust/fetch-cargo-tarball/default.nix

{
  lib,
  fetchFromGitHub,
  rustPlatform,
}:

# To rebuild: rm result && nix-collect-garbage && nix-build . -A comtrya
# (better in the nixos/nix container)
# TODO: better way of rebuilding? These steps will re-copy the dependencies.
rustPlatform.buildRustPackage rec {
  pname = "comtrya";
  version = "18e9573597c252f7f260060677a445801187e62b";

  # have to comment out the hash if the repo is updated (version unchanged):
  src = fetchFromGitHub {
    owner = "z1gc";
    repo = "${pname}";
    rev = version;
    hash = "sha256-QGz5k/fEfclQGUDJuz4PwNYVZiG1jNXHmU+geW+fFGk=";
  };

  # filling with `lib.fakeHash` first, then re-run to get the correct hash:
  cargoHash = "sha256-qHVHRzXCKSM9OgsMJggyBa4+sFoqQ3KbmsxgJV/GUQk=";
  doCheck = false;

  meta = with lib; {
    description = "Configuration Management for Localhost / dotfiles";
    mainProgram = "comtrya";
    homepage = "https://github.com/comtrya/comtrya";
    license = licenses.mit;
  };
}
