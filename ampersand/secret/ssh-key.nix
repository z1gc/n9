{ ... }: # <- Flake inputs

# Making the Fish shell.
# @input priv: The ssh private key file.
# @input pub: The corresponding public key.
priv: pub: # <- Module arguments.

{ config, ... }: # <- Nix `imports = []`

let
  keyName = builtins.baseNameOf priv;
in
{
  sops.secrets.ssh-key = {
    format = "binary";
    sopsFile = priv;
    path = "${config.home.homeDirectory}/.ssh/${keyName}";
  };

  home.file.".ssh/${keyName}.pub" = {
    enable = true;
    force = true;
    text = pub;
  };
}
