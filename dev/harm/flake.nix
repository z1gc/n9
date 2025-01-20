{
  inputs.n9.url = "../../irix";

  outputs = { n9, ... }: n9.lib.mkNixosSystem ./. {
    system = "aarch64-linux";

    modules = with n9.lib.modules; [
      ./hardware-configuration.nix
      (mkDisk { device = "/dev/sda"; })

      (mkHomeManager {
        user = "byte";
        uid = 1000;

        modules = with n9.lib.home-modules; [
          (mkHelix {})
          (mkFish {})
        ];
      })

      ({ pkgs, ... }: {
        boot.kernelPackages = pkgs.linuxPackagesFor
          (pkgs.callPackage ./pkgsLinuxKernelWSL2.nix {});
        virtualisation.hypervGuest = {
          enable = true;
          videoMode = "1280x720";
        };
      })
    ];
  };
}
