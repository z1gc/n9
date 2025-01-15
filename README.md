# N9

Configurations of mine, powered by NixOS + Flake :)

N9 is abbr of N-IX, so freaking bad joke.

# .*

Setup with [nixos-anywhere](https://github.com/nix-community/nixos-anywhere),
try to keep everything in one place.

For setting things up, you need to run a machine which has nix installed:

```bash
# warning: it wipes disk
./burn.sh setup -t root@172.20.48.127 harm

# rebuild and switch:
./burn.sh switch

# or switch a remote machine:
./burn.sh switch -t byte@172.20.48.254 evil
```

For path structure:

* asterisk: contains scripts to setup secrets, avoid exposing to `/nix/store`
* burn.sh:  helper script for setup machine
* nixos:    everything inside
* pkgs:     some self-maintained packages

Break it!
