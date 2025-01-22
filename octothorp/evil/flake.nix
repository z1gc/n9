{
  inputs.n9.url = "../../ampersand";

  outputs =
    { self, n9, ... }:
    {
      system = "x86_64-linux";

      nixosConfigurations = n9.lib.nixos self {
        modules = with n9.lib.nixos-modules; [
          ./hardware-configuration.nix
          (disk.zfs "/dev/nvme0n1")
          desktop.gnome
        ];
      };

      homeConfigurations = n9.lib.home self (n9.lib.utils.user2 "byte" ./passwd) {
        packages = [
          "git-repo"
          "jetbrains.clion"
        ];

        modules = with n9.lib.home-modules; [
          editor.helix
          shell.fish
          (
            { config, ... }:
            {
              sops.secrets.ssh-config = {
                format = "binary";
                sopsFile = ./ssh-config;
              };
              programs.ssh = {
                enable = true;
                includes = [ config.sops.secrets.ssh-config.path ];
              };
            }
          )
          # TODO: Generate the pubkey from private.
          (secret.ssh-key ./id_ed25519 "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICw9akIf3We4wbAwVfaqr8ANZYHLbtQ5sQGz1W5ZUE8Y byte@evil")
        ];
      };
    };
}
