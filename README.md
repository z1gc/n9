# N9

NixOS configurations of mine.

# .*

```nix
{ stdenv, ... }:

stdenv.mkDerivation {
  pname = "n9";
  version = "unstable";
  meta = { description = "N-IX"; };

  buildPhase = "make setup";
  installPhase = "make switch";
}
```

Break it!
