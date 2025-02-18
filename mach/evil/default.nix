{ self, n9, ... }:

let
  secret = "@ASTERISK@/evil";
in
{
  nixosConfigurations = n9.lib.nixos self "evil" "x86_64-linux" {
    modules = with n9.lib.nixos-modules; [
      ./hardware-configuration.nix
      (disk.zfs "/dev/disk/by-id/nvme-eui.002538b231b633a2")
    ];
  };

  homeConfigurations = n9.lib.home self "byte" "${secret}/passwd" {
    packages = [
      "git-repo"
      "jetbrains.clion"
    ];

    modules = with n9.lib.home-modules; [
      editor.helix
      shell.fish
      desktop.pop-shell
      v12n.boxes
      { programs.ssh.includes = [ "config.d/*" ]; }
    ];

    deployment.keys = (n9.lib.utils.sshKey "${secret}/id_ed25519") // {
      hosts = {
        keyFile = "${secret}/ssh";
        destDir = "@HOME@/.ssh/config.d";
      };
    };
  };
}
