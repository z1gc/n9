{ ... }@args:

{ lib, ... }:
let
  port = if args ? port then lib.mkForce port else lib.mkDefault 22;
in
{
  services.openssh = {
    enable = true;
    ports = [ port ];
    authorizedKeysFiles = [ "/etc/ssh/agent_keys.d/%u" ];
  };
  networking.firewall.allowedTCPPorts = [ port ];

  # Fine-gran control of which user can use PAM to authorize things.
  security.pam = {
    sshAgentAuth = {
      enable = true;
      authorizedKeysFiles = [ "/etc/ssh/agent_keys.d/%u" ];
    };
    services.sudo.sshAgentAuth = true;
  };
}
