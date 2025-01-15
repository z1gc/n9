# https://nixos-and-flakes.thiscute.world/zh/nixos-with-flakes/start-using-home-manager
# Can have osConfig in the argument for NixOS configuration, unused.

{ subconf, pkgs, lib, ... }:

let
  gnome = subconf.gnome or false;
in {
  imports = [
    ./fish.nix
    ./helix.nix
  ];

  users.groups."${subconf.group.name}".gid = subconf.group.gid;
  users.users."${subconf.user.name}" = {
    isNormalUser = true;
    uid = subconf.user.uid;
    group = subconf.group.name;
    extraGroups = [ "wheel" ];
  };

  home-manager = {
    useUserPackages = true;
    useGlobalPkgs = true;

    # home.username, home.homeDirectory: @see home-manager/nixos/common.nix
    users."${subconf.user.name}".home = {
      # The programs are set in modules imported.
      packages = with pkgs; [
        # VCS
        git-repo

        # Shell
        zoxide
        ripgrep
        fd
        fzf
        sysstat
        grc
        lm_sensors

        # Devel
        nixd
        clang-tools
      ] ++ lib.optionals gnome [
        # Devel
        jetbrains.clion
      ];

      # No need to worry:
      stateVersion = "24.11";
    };
  };
}
