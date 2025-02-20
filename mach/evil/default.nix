{ self, n9, ... }:

let
  secret = "@ASTERISK@/evil";
in
{
  nixosConfigurations = n9.lib.nixos self "evil" "x86_64-linux" {
    modules = with n9.lib.nixos-modules; [
      ./hardware-configuration.nix
      (disk.zfs "/dev/disk/by-id/nvme-eui.002538b231b633a2")
      (miscell.sshd { })
    ];
  };

  homeConfigurations = n9.lib.home self "byte" "${secret}/passwd" {
    packages = [
      "git-repo"
      "jetbrains.clion"
    ];

    modules = with n9.lib.home-modules; [
      shell.fish
      desktop.pop-shell
      v12n.boxes
      { programs.ssh.includes = [ "config.d/*" ]; }
      miscell.git
      (miscell.ssh {
        ed25519.private = "${secret}/id_ed25519";
        # ed25519.public = "";
      })
    ];

    secrets = n9.lib.utils.secret "${secret}/ssh" ".ssh/config.d/hosts";
  };
}
