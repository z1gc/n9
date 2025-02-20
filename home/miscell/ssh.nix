{ self, nixpkgs, ... }: # <- Flake inputs

# SSH, private, public, or else
# @input ed25519.private: Private ed25519 key path (absolute) for SSH.
# @input ed25519.public: Public key of it, can be fetched by other nodes.
# @input authorizedKeys: SSH public keys for authorizing.
# @input agentKeys: For passwordless SSH sudo, it's a little risky, but it is
#                   is needed for colmena.
{
  ed25519 ? { },
  authorizedKeys ? null,
  agentKeys ? null,
}:

let
  inherit (nixpkgs) lib;

  convert = builtins.map (
    key:
    let
      # ssh-ed25519 byte@evil
      split = lib.splitString " " key;
      type = builtins.elemAt (lib.splitString "-" (builtins.elemAt split 0)) 1;
      pair = lib.splitString "@" (builtins.elemAt split 1);
      username = builtins.elemAt pair 0;
      hostname = builtins.elemAt pair 1;
    in
    if builtins.length split == 3 then
      key
    else if builtins.length split == 2 then
      self.nixosConfigurations.${hostname}.config.home-manager.users.${username}.home.file.".ssh/id_${type}.pub".text
    else
      assert lib.assertMsg false "invalid public format!";
      ""
  );
in
{
  __nixos__ = username: [
    (lib.optionalAttrs (authorizedKeys != null) {
      users.users.${username}.openssh.authorizedKeys.keys = convert authorizedKeys;
    })

    (lib.optionalAttrs (agentKeys != null) {
      environment.etc."ssh/agent_keys.d/${username}" = {
        text = builtins.concatStringsSep "\n" (convert agentKeys);
        mode = "0644";
      };
    })

    (lib.optionalAttrs (authorizedKeys != null || agentKeys != null) (
      self.lib.nixos-modules.miscell.sshd { }
    ))
  ];

  __home__ = [
    (lib.optionalAttrs (ed25519 ? public) {
      home.file.".ssh/id_ed25519.pub".text = ed25519.public;
    })
  ];

  # TODO: unify for all home modules? better idea for managing them?
  __secrets__ = lib.optionalAttrs (ed25519 ? private) (
    self.lib.utils.secret ed25519.private ".ssh/id_ed25519"
  );
}
