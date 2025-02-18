{ nixpkgs, ... }:

let
  mkPatches =
    patches: pkg: pkgs:
    pkg.overrideAttrs (prev: {
      patches = (prev.patches or [ ]) ++ (builtins.map pkgs.fetchpatch patches);
    });
  mkPatch = patch: mkPatches [ patch ];

in
{
  # A little bit clean way to add patches, and a single patch:
  inherit mkPatches mkPatch;

  # Turn "xyz" to pkgs.xyz (only if "xyz" is string) helper:
  attrByIfStringPath =
    set: maybeStringPath:
    if (builtins.typeOf maybeStringPath == "string") then
      nixpkgs.lib.attrsets.attrByPath (nixpkgs.lib.strings.splitString "." maybeStringPath) null set
    else
      maybeStringPath;

  # Setup SSH keys:
  sshKey =
    path:
    let
      key = builtins.baseNameOf path;
    in
    {
      # ssh-keygen -f [private] -y > [public]
      ${key} = {
        keyFile = path;
        permissions = "0400";
        destDir = "@HOME@/.ssh";
      };
    };
}
