# https://github.com/nix-community/disko/tree/master/example
# To test:
# nix build --print-out-paths --no-link --no-write-lock-file ".#nixosConfigurations.evil.config.system.build.diskoScript"
# Then cat and review the contents.
# BUT DON'T EXECUTE IT, ESPECIALLY YOU'RE RUNNING AS ROOT OR SUDO!

{ subconf, lib, ... }:

let
  zfs = subconf.zfs or false;
in {
  disko.devices.disk.first = {
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
        content = if zfs then {
          type = "zfs";
          pool = "mix";
        } else {
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

  disko.devices.zpool = lib.optionalAttrs zfs {
    mix = {
      type = "zpool";
      options.ashift = "13";
      rootFsOptions.compression = "zstd";
      datasets.root = {
        type = "zfs_fs";
        mountpoint = "/";
      };
      datasets.home = {
        type = "zfs_fs";
        mountpoint = "/home";
        options.dedup = "on";
      };
      datasets.nix = {
        type = "zfs_fs";
        mountpoint = "/nix";
      };
    };
  };
}
