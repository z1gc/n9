{
  inputs.n9.url = "../../irix";

  outputs = { n9, ... }: n9.lib.mkNixosSystem ./. {
    system = "x86_64-linux";

    modules = with n9.lib.modules; [
      ./hardware-configuration.nix
      (mkDisk {
        type = "zfs";
        device = "/dev/nvme0n1";
      })

      (mkGnome {})

      # TODO: To handle the pkgs better, nixpkgs.legacyPackages.${system} is
      # kind of noisy :/
      ({ pkgs, ... }@args: mkHomeManager {
        user = "byte";
        uid = 1000;

        packages = with pkgs; [
          git-repo
          jetbrains.clion
        ];
        modules = with n9.lib.home-modules; [
          (mkHelix {})
          (mkFish {})
        ];
      } args)
    ];
  };
}
