# This should be as simple as it can.
# For arguments, you might need to adjust the flake.nix to pass them.

{
  # Required:
  hostid = "2bff42a8";
  disk.first = "/dev/sda";
  user = { name = "byte"; uid = 1000; };
  group = { name = "byte"; gid = 1000; };

  # Optional:
  hyperv = true;
  gnome = true;
}
