# @see nixpkgs/pkgs/by-name/ri/rime-data/package.nix
# TODO: home-manager?
# If updated, you might need to run `ibus-daemon -drx` for taking effects.

# From pkgs? args == pkgs?
{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchpatch,
  librime,
  ...
}:

let
  pname = "rime-ice";
  version = "298b3967b84ba49e4cd6e0f9595de60517d76f4e";
in
stdenv.mkDerivation {
  inherit pname version;

  src = fetchFromGitHub {
    owner = "iDvel";
    repo = "rime-ice";
    rev = version;
    hash = "sha256-EnCB/ChsZGnlFVgEKEvDOYe20fltU8qqki8I9GGlbPA=";
  };

  # Can't have any 'custom' things, they should be in $XDG, uhho.
  patches = fetchpatch {
    url = "https://github.com/plxty/rime-ice/commit/662be70ff5acbbc0a054b096cc44dbb2fb925966.patch";
    hash = "sha256-9xJ4gcPYpa8A9qcHzDZFDnoffQPuR7k1LqJ0Kktr33c=";
  };

  buildInputs = [ librime ];

  # https://discourse.nixos.org/t/what-does-runhook-do/13861/3
  # Reference other package with `${}` which will expands in nix,
  # reference for out dir with `$out` which will expands in build shell script.

  # TODO: Build as https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=rime-ice-git
  # ${librime}/bin/rime_deployer --build
  buildPhase = ''
    runHook preBuild
    rm -rf .* opencc others LICENSE README.md
    runHook postBuild
  '';

  # TODO: use install -d...
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/rime-data"
    cp -r . "$out/share/rime-data"
    runHook postInstall
  '';

  meta = {
    homepage = "https://dvel.me/posts/rime-ice/";
    license = with lib.licenses; [ gpl3 ];
  };
}
