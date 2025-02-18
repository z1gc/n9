args:
let
  disk = type: device: (import ./disk args) { inherit type device; };
in
{
  disk.zfs = disk "zfs";
  disk.btrfs = disk "btrfs";
  desktop.gnome = import ./desktop/gnome.nix;
  miscell.sshd = import ./miscell/sshd.nix;
}
