{ nixpkgs, sops-nix, ... }:

# Making a Home Manager things.
# @input {username,uid,home,passwd}: Information about the user.
#                                    The group's info is same as the user.
# @input modules: Imports from.
# @input packages: Shortcut of home.packages, within the imports context.
#                  Due to this restriction, this should be array of strings.
#                  For other packages, you might need to write a module.
# @output: AttrSet of ${username} = {uid,home,passwd,config}
{
  username,
  uid ? 1000,
  home ? "/home/${username}",
  passwd ? null,
}:
{
  packages ? [ ],
  modules ? [ ],
}:

let
  # https://www.reddit.com/r/NixOS/comments/1cnwfyi/comment/l3a38q5/
  attrByStrPath =
    set: strPath:
    nixpkgs.lib.attrsets.attrByPath (nixpkgs.lib.strings.splitString "." strPath) null set;
in
{
  ${username} = {
    inherit
      uid
      home
      passwd
      ;

    config = {
      imports = [
        sops-nix.homeManagerModules.sops
        (
          { pkgs, ... }:
          {
            home.packages = map (attrByStrPath pkgs) packages;
            sops.age.keyFile = "${home}/.cache/.whats-yours-is-mine";
          }
        )
      ] ++ modules;

      home = {
        inherit username;
        homeDirectory = home;
        stateVersion = "25.05";
      };
    };
  };
}
