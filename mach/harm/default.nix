{ self, n9, ... }:

let
  secret = "@ASTERISK@/harm";
in
{
  colmenaHive = n9.lib.nixos self "harm" "aarch64-linux" {
    modules = with n9.lib.nixos-modules; [
      ./hardware-configuration.nix
      (
        { pkgs, ... }:
        {
          boot.kernelPackages = pkgs.linuxPackagesFor (pkgs.callPackage ./linux-kernel-wsl2.nix { });

          # https://github.com/nix-community/nixos-anywhere/issues/18#issuecomment-1500952398
          # https://colmena.cli.rs/unstable/examples/multi-arch.html
          # It takes some times if no nix store cache available...
          # Maybe remote build if the target machine has enough performance.
          # boot.binfmt.emulatedSystems = [ "x86_64-linux" ];
        }
      )
      (disk.btrfs "/dev/sda")
    ];
  };

  homeConfigurations = n9.lib.home self "byte" "${secret}/passwd" {
    modules = with n9.lib.home-modules; [
      editor.helix
      shell.fish
    ];
    deployment.keys = n9.lib.utils.sshKey "${secret}/id_ed25519";
  };
}
