{
  lib,
  fetchFromGitHub,
  rustPlatform,
}:

rustPlatform.buildRustPackage rec {
  pname = "comtrya";
  version = "unstable";

  src = fetchFromGitHub {
    owner = "z1gc";
    repo = "${pname}";
    rev = "fa5cd169ba0081c9ae0ca379dc2dd1d22e3fa118";
    hash = "sha256-Vy2xKgz1Dp/18D6ucS1oT59b2HffbV6IX4W88SRYU2Q=";
  };

  cargoHash = "sha256-ezQ6r+dL9qk1wos31uhzkDv5AAnSFdtZjWKyHXOlOYU=";
  doCheck = false;

  meta = with lib; {
    description = "Configuration Management for Localhost / dotfiles";
    mainProgram = "comtrya";
    homepage = "https://github.com/comtrya/comtrya";
    license = with licenses; [ mit ];
  };
}
