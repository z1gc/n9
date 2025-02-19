{ nixpkgs, ... }:

rec {
  # A little bit clean way to add patches, and a single patch:
  mkPatches =
    patches: pkg: pkgs:
    pkg.overrideAttrs (prev: {
      patches = (prev.patches or [ ]) ++ (builtins.map pkgs.fetchpatch patches);
    });
  mkPatch = patch: mkPatches [ patch ];

  # Turn "xyz" to pkgs.xyz (only if "xyz" is string) helper:
  attrByIfStringPath =
    set: maybeStringPath:
    if (builtins.typeOf maybeStringPath == "string") then
      nixpkgs.lib.attrsets.attrByPath (nixpkgs.lib.strings.splitString "." maybeStringPath) null set
    else
      maybeStringPath;

  # Secret. TODO: duplicate key? colmena have bug dealing with `keys.name`.
  secret =
    keyFile: dest:
    let
      name = builtins.baseNameOf dest;
      destDir = builtins.dirOf dest;
    in
    {
      ${name} = { inherit keyFile destDir; };
    };

  # ssh-keygen -f [private] -y > [public]
  sshKey = path: secret path ".ssh/${builtins.baseNameOf path}";
}
