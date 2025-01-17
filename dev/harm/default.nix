# This should be as simple as it can.
# For arguments, you might need to adjust the flake.nix to pass them.

{
  # Required:
  system = "aarch64-linux";
  hostid = "2bff42a8";
  disk.first = "/dev/sda";

  # Optional:
  hyperv = true;

  # Toplevel:
  toplevel = { ... }: {
    imports = [ ./hardware-configuration.nix ];
  };
}
