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

    deployment.targetHost = "localhost";
  };

  homeConfigurations = n9.lib.home self "byte" "${secret}/passwd" {
    modules = with n9.lib.home-modules; [
      editor.helix
      shell.fish
      desktop.pop-shell
      miscell.git
    ];
  };
}
