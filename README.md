# N9.*

```nix
{ stdenv, gnumake, ... }:

stdenv.mkDerivation {
  # n-ix, yes, the n9 :O
  pname = "n";
  version = "ix";
}
```

NixOS (partial) configurations of mine. Break it!

# ()ctothorp

```bash
# switch local
nix run

# or remote
nix run . evil

# nixos-anywhere install
nix run .#install evil

# nix gc
nix run .#gc
```

Checkout `mach` directory for my own builds, using [colmena](https://github.com/zhaofengli/colmena).
