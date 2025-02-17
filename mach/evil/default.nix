{ self, n9, ... }:

let
  secret = "@ASTERISK@/evil";
in
{
  colmenaHive = n9.lib.nixos self "evil" "x86_64-linux" {
    modules = with n9.lib.nixos-modules; [
      ./hardware-configuration.nix
      (disk.zfs "/dev/disk/by-id/nvme-eui.002538b231b633a2")
      desktop.gnome
      (
        { pkgs, ... }:
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
        }
      )
    ];
  };

  homeConfigurations = n9.lib.home self "byte" "${secret}/passwd" {
    groups = [ "libvirtd" ];

    packages = [
      "git-repo"
      "jetbrains.clion"
      "pop-launcher"
      "dconf-editor"
      "gnome-boxes"
    ];

    modules = with n9.lib.home-modules; [
      editor.helix
      shell.fish
      (
        { pkgs, config, ... }:
        {
          programs.ssh.includes = [ "config.d/*" ];

          # TODO: desktop.gnome, dconf
          programs.gnome-shell = {
            enable = true;
            extensions = [
              { package = pkgs.gnomeExtensions.pop-shell; }
              { package = pkgs.gnomeExtensions.customize-ibus; }
            ];
          };

          home.file."${config.xdg.configHome}/libvirt/qemu.conf".text = ''
            nvram = [ "/run/libvirt/nix-ovmf/AAVMF_CODE.fd:/run/libvirt/nix-ovmf/AAVMF_VARS.fd", "/run/libvirt/nix-ovmf/OVMF_CODE.fd:/run/libvirt/nix-ovmf/OVMF_VARS.fd" ]
          '';
        }
      )
    ];

    deployment.keys = (n9.lib.utils.sshKey "${secret}/id_ed25519") // {
      hosts = {
        keyFile = "${secret}/ssh";
        destDir = "@HOME@/.ssh/config.d";
      };
    };
  };
}
