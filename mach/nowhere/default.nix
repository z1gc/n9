{ self, n9, ... }:

{
  # Kind of a template.
  colmenaHive = n9.lib.nixos self "nowhere" "x86_64-linux" {
    modules = with n9.lib.nixos-modules; [
      ./hardware-configuration.nix
      (disk.btrfs "/dev/vda")
    ];

    # ssh -R within vm
    deployment = {
      targetHost = "127.0.0.1";
      targetPort = 2233;
      targetUser = "zNFoK8jJUQvT3zDK";
      targetKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICw9akIf3We4wbAwVfaqr8ANZYHLbtQ5sQGz1W5ZUE8Y byte@evil";
    };
  };

  # Just a test virtual machine under evil, for simplicity.
  homeConfigurations = n9.lib.home self "byte" "@ASTERISK@/evil/passwd" {
    modules = with n9.lib.home-modules; [
      editor.helix
      shell.fish
    ];
  };
}
