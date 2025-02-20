# <- Flake inputs

# GNOME Boxes, with libvirtd as backend.

{
  __nixos__ =
    username: # <- Module arguments (for NixOS)
    [
      (
        { pkgs, ... }: # <- NixOS imports
        {
          # https://nixos.wiki/wiki/Libvirt
          virtualisation.libvirtd =
            let
              ovmf = {
                enable = true;
                packages = [
                  (pkgs.OVMF.override {
                    secureBoot = true;
                    tpmSupport = true;
                  }).fd
                ];
              };
            in
            {
              enable = true;
              qemu = {
                package = pkgs.qemu_kvm;
                runAsRoot = true;
                swtpm.enable = true;
                inherit ovmf;
              };
            };

          # TODO: avoid argument in here? pass into like { pkgs, username }?
          users.users.${username}.extraGroups = [ "libvirtd" ];
        }
      )
    ];

  __home__ = [
    (
      { config, pkgs, ... }:
      {
        home.packages = [ pkgs.gnome-boxes ];
        home.file."${config.xdg.configHome}/libvirt/qemu.conf".text = ''
          nvram = [ "/run/libvirt/nix-ovmf/AAVMF_CODE.fd:/run/libvirt/nix-ovmf/AAVMF_VARS.fd", "/run/libvirt/nix-ovmf/OVMF_CODE.fd:/run/libvirt/nix-ovmf/OVMF_VARS.fd" ]
        '';
      }
    )
  ];
}
