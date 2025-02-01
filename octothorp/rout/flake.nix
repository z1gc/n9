{
  inputs.n9.url = "../../ampersand";

  outputs =
    { self, n9, ... }@args:
    {
      system = "x86_64-linux";

      nixosConfigurations = n9.lib.nixos self {
        modules = with n9.lib.nixos-modules; [
          ./hardware-configuration.nix
          (disk.btrfs "/dev/mmcblk0")
          (import ./networking.nix args)
        ];
      };

      homeConfigurations = n9.lib.home self (n9.lib.utils.user2 "byte" ./passwd) {
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
          {
            home.file.".ssh/authorized_keys".text =
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILb5cEj9hvj32QeXnCD5za0VLz56yBP3CiA7Kgr1tV5S byte@harm";
          }
        ];
      };
    };
}
