args: {
  desktop.pop-shell = import ./desktop/pop-shell.nix args;
  v12n.boxes = import ./v12n/boxes.nix;
  miscell.git = import ./miscell/git.nix;
  miscell.ssh = import ./miscell/ssh.nix args;
}
