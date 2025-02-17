{ self, n9, ... }:

let
  secret = "@ASTERISK@/rout";
  key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILb5cEj9hvj32QeXnCD5za0VLz56yBP3CiA7Kgr1tV5S byte@harm";
in
{
  colmenaHive = n9.lib.nixos self "rout" "x86_64-linux" {
    modules = with n9.lib.nixos-modules; [
      ./hardware-configuration.nix
      (disk.btrfs "/dev/mmcblk0")
      (import ./networking.nix)
    ];

    deployment = {
      # For remote build, there's no need to use targetKey as it won't use
      # the (host) remote builder of nix.
      # Just using to keep consistency of experience. TODO: Make a new ssh key!
      buildOnTarget = true;
      targetHost = "10.0.0.1";
      targetUser = "z3gWLm65AkW5xEPy";
      targetKey = key;

      keys.wan = {
        keyFile = "${secret}/wan";
        destDir = "/etc/ppp/secrets";
        permissions = "0400";
      };
    };
  };

  homeConfigurations = n9.lib.home self "byte" "${secret}/passwd" {
    packages = [
      "bridge-utils"
      "tcpdump"
      "mstflint"
      "ethtool"
      "nftables"
    ];

    modules = with n9.lib.home-modules; [
      editor.helix
      shell.fish
    ];

    authorizedKeys = [ key ];
  };
}
