{ home-manager, ... }:

# Making a Home Manager things.
# @input home.user: The username managed by home-manager, will be created.
# @input home.group: The main group of this user, blank for same as the user.
# @input home.uid: The uid
# @input home.gid: The main GID of this user, blank for same as the UID.
# @input packages: Passthru to home-manager.users.${user}.home.packages.
# @input modules: Imports from.
{
  user,
  group ? user,
  uid ? 1000,
  gid ? uid,
  packages ? [],
  modules ? []
}:

{ ... }:
let
  tryImport = mod: (if builtins.typeOf mod == "string"
    then (import mod)
    else mod) { inherit user; };

  imports = [
    home-manager.nixosModules.home-manager
  ] ++ (map tryImport modules);
in {
  inherit imports;

  # TODO: Move to mkUser? Or just use the mkHomeManager instead, it's tiny.
  users = {
    groups.${group} = {
      inherit gid;
    };

    users.${user} = {
      isNormalUser = true;
      inherit uid group;
      extraGroups = [ "wheel" ];
    };
  };

  home-manager = {
    useUserPackages = true;
    useGlobalPkgs = true;

    users.${user}.home = {
      inherit packages;
      stateVersion = "25.05";
    };
  };
}
