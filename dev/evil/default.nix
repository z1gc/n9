# This should be as simple as it can.
# For arguments, you might need to adjust the flake.nix to pass them.

{
  # Required:
  system = "x86_64-linux";
  hostid = "2bff42a7";
  disk.first = "/dev/nvme0n1";

  # Optional:
  zfs = true;
  gnome = true;

  # Toplevel:
  toplevel = { ... }: {
    imports = [ ./hardware-configuration.nix ];
  };
}
