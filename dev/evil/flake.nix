{
  inputs.n9.url = "../../irix";
  inputs.asterisk.url = "../../asterisk";

  outputs = { n9, asterisk, ... }:
    let hostName = "evil";
    in n9.lib.mkNixosSystem hostName {
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

          packages = with pkgs; [
            git-repo
            jetbrains.clion
          ];
          modules = with n9.lib.home-modules; [
            (mkHelix {})
            (mkFish {})
            (builtins.toPath "${asterisk.lib.self}/dev/${hostName}")
          ];
        } args)
      ];
    };
}
