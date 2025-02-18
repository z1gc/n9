args: {
  desktop.pop-shell = import ./desktop/pop-shell.nix args;
  editor.helix = import ./editor/helix.nix;
  shell.fish = import ./shell/fish.nix;
  v12n.boxes = import ./v12n/boxes.nix;
  miscell.git = import ./miscell/git.nix;
}
