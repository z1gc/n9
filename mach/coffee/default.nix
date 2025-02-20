{ self, n9, ... }:

let
  secret = "@ASTERISK@/coffee";
in
{
  nixosConfigurations = n9.lib.nixos self "coffee" "x86_64-linux" {
    modules = with n9.lib.nixos-modules; [
      ./hardware-configuration.nix
      (disk.btrfs "/dev/nvme0n1")
      (miscell.sshd { })
    ];
  };

  homeConfigurations = n9.lib.home self "byte" "${secret}/passwd" {
    modules = with n9.lib.home-modules; [
      desktop.pop-shell
      miscell.git
      (miscell.ssh {
        ed25519.private = "${secret}/id_ed25519";
        ed25519.public = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBESP6hsTtRCTRchPimo4JVKnhP3l7ydhz49R4CBUyU7 byte@coffee";
      })
    ];
  };
}
