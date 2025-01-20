{ disko, ... }:  # <- Flake inputs

# Make a disk with disko, using this module should ensure the mount options
# isn't exist in the hardware-configuration.nix.
# @input disk.type: The main disk type, BTRFS or ZFS.
# @input disk.device: The main disk in /dev/XXX.
{ type ? "btrfs", device }:  # <- Module arguments

{ lib, ... }:  # <- Nix `imports = []`
let
  base = {
    imports = [ disko.nixosModules.disko ];

    disko.devices.disk.first = {
      type = "disk";
      inherit device;

      content = {
        type = "gpt";

        partitions.ESP = {
          name = "ESP";
          priority = 1; start = "1M"; size = "1G"; type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/efi"; mountOptions = [ "umask=0077" ];
          };
        };

        partitions.swap = {
          name = "swap";
          priority = 2; size = "16G";
          content.type = "swap";
        };

        partitions.root = {
          name = "root";
          priority = 3; size = "100%";
        };
      };
    };
  };

  mixin = if type == "btrfs" then {
    disko.devices.disk.first.content.partitions.root.content = {
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
  }
  else if type == "zfs" then {
    disko.devices.disk.first.content.partitions.root.content = {
      type = "zfs";
      pool = "mix";
    };

    disko.devices.zpool.mix = {
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
  }
  else builtins.abort "Unsupported type in disk?";
in lib.recursiveUpdate base mixin
