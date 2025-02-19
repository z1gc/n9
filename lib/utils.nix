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

  # Secret:
  secret3 = name: keyFile: destDir: {
    ${name} = { inherit keyFile destDir; };
  };
  secret2 = path: secret3 (builtins.baseNameOf path) path;

  # ssh-keygen -f [private] -y > [public]
  sshKey = path: secret2 path ".ssh";
}
