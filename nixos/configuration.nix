# AttrSet of system:

{ host, subconf, pkgs, ... }:
{
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    substituters = [ "https://mirrors.ustc.edu.cn/nix-channels/store" ];
  };

  # TODO: system.copySystemConfiguration = true;
  system.stateVersion = "24.11";

  # https://github.com/nix-community/disko/tree/master/example
  disko.devices = {
    disk.first = {
      type = "disk";
      device = subconf.disk.first;
      content = {
        type = "gpt";
        partitions.ESP = {
          name = "ESP";
          priority = 1; start = "1M"; end = "1G"; type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/efi"; mountOptions = [ "umask=0077" ];
          };
        };
        partitions.swap = {
          name = "swap";
          priority = 2; start = "1G"; end = "16G"; type = "8200";
          content.type = "swap";
        };
        partitions.root = {
          name = "root";
          priority = 3; size = "100%"; type = "8304";
          content = {
            type = "btrfs";
            extraArgs = [ "-f" ];
            subvolumes."/@root" = {
              mountpoint = "/"; mountOptions = [ "compress=zstd" ];
            };
            subvolumes."/@home" = {
              mountpoint = "/home"; mountOptions = [ "compress=zstd" ];
            };
            subvolumes."/@nix" = {
              mountpoint = "/nix";
              mountOptions = [ "compress=zstd" "noatime" ];
            };
          };
        };
      };
    };
  };

  boot.loader = {
    systemd-boot.enable = true;
    efi.efiSysMountPoint = "/efi";
    efi.canTouchEfiVariables = true;
  };

  networking = {
    hostName = host;
    networkmanager.enable = true;
    firewall.allowedTCPPorts = [ 22 ];
    firewall.allowedUDPPorts = [ ];
  };

  time.timeZone = "Asia/Shanghai";
  i18n.defaultLocale = "zh_CN.UTF-8";

  users.groups."${subconf.group.name}".gid = subconf.group.gid;
  users.users."${subconf.user.name}" = {
    isNormalUser = true;
    uid = subconf.user.uid;
    group = subconf.group.name;
    extraGroups = [ "wheel" ];
  };

  environment = {
    systemPackages = with pkgs; [
      git
      helix
      nixd
    ];
  };

  services.openssh = {
    enable = true;
    ports = [ 22 ];
  };
}
