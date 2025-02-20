{ self, n9, ... }:

let
  secret = "@ASTERISK@/rout";
in
{
  nixosConfigurations = n9.lib.nixos self "rout" "x86_64-linux" {
    modules = with n9.lib.nixos-modules; [
      ./hardware-configuration.nix
      (disk.btrfs "/dev/mmcblk0")
      ./networking.nix
    ];

    deployment = {
      buildOnTarget = true;
      targetHost = "rout.y.xas.is";
      targetUser = "byte";
    };

    secrets = n9.lib.utils.secret "${secret}/wan" "/etc/ppp/secrets/wan";
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
      (miscell.ssh { agentKeys = [ "ssh-ed25519 byte@coffee" ]; })
    ];
  };
}
