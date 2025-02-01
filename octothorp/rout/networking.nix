{ n9, ... }:

# https://krutonium.ca/posts/building-a-nixos-router/
# https://francis.begyn.be/blog/ipv6-nixos-router
# https://github.com/ghostbuster91/blogposts/blob/main/router2023-part2/main.md
# https://nixos.wiki/wiki/Networking
# https://nixos.wiki/wiki/Systemd-networkd

# 10.0.0.1 => Router
# 10.254.0.0 => DHCP
# 10.29.0.0 => PXE (later)
# 10.42.0.0 => Proxy
# May conflicts with?

{
  lib,
  config,
  ...
}:

let
  ports = {
    # physical
    rj45-0 = "enp1s0";
    rj45-1 = "enp2s0";
    rj45-2 = "enp4s0";
    sfp-0 = "enp5s0f1np1";
    sfp-1 = "enp5s0f0np0";

    # virtual
    vlan = "enp5s0f1.101";
    wan = "pppoe-wan";
    lan = "br-lan";
    iptv = "br-iptv";
  };

  # Without link local address and required online by default:
  mkNetwork =
    port:
    lib.recursiveUpdate {
      matchConfig.Name = port;
      networkConfig = {
        LinkLocalAddressing = "no";
        DHCP = "no";
      };
      linkConfig.RequiredForOnline = "carrier";
    };

  mkBridge =
    port:
    lib.recursiveUpdate {
      netdevConfig = {
        Kind = "bridge";
        Name = port;
      };
    };

  mkBridgeSlave =
    port: master:
    lib.recursiveUpdate (
      mkNetwork port {
        matchConfig.Name = port;
        networkConfig.Bridge = master;
        linkConfig.RequiredForOnline = "enslaved";
      }
    );
in
{
  # Netdev:
  systemd.network.enable = true;

  systemd.network.netdevs = {
    "10-vlan" = {
      netdevConfig = {
        Kind = "vlan";
        Name = ports.vlan;
      };
      vlanConfig.Id = 101;
    };

    "20-lan" = mkBridge ports.lan { };
    "21-iptv" = mkBridge ports.iptv {
      bridgeConfig.VLANFiltering = "yes";
    };
  };

  # PPPoE (netdev), networkd managed as well:
  boot.kernelModules = [ "pppoe" ];
  sops.secrets.pppoe-wan = n9.lib.utils.sopsBinary ./pppoe-wan;

  services.pppd = {
    enable = true;
    # https://man7.org/linux/man-pages/man8/pppd.8.html
    peers.wan.config = ''
      plugin pppoe.so
      ifname ${ports.wan}
      nic-${ports.vlan}
      file ${config.sops.secrets.pppoe-wan.path}

      persist
      maxfail 0
      holdoff 10

      +ipv6 ipv6cp-use-ipaddr
      defaultroute
      usepeerdns
      noipdefault
    '';
  };

  # Networks:
  systemd.network.networks = {
    "10-sfp-0" = mkBridgeSlave ports.sfp-0 ports.iptv {
      vlan = [ ports.vlan ];
    };
    "11-vlan" = mkNetwork ports.vlan { };

    "20-wan" = mkNetwork ports.wan {
      networkConfig.KeepConfiguration = "yes";
      linkConfig.RequiredForOnline = "yes"; # TODO: Is it really working?
    };

    "30-rj45-0" = mkBridgeSlave ports.rj45-0 ports.lan { };
    "31-rj45-1" = mkBridgeSlave ports.rj45-1 ports.lan { };
    "32-sfp-1" = mkBridgeSlave ports.sfp-1 ports.lan { };
    "33-lan" = mkNetwork ports.lan {
      networkConfig.Address = "10.0.0.1/8";
    };

    "40-rj45-2" = mkBridgeSlave ports.rj45-2 ports.iptv { };
    "41-iptv" = mkNetwork ports.iptv {
      bridgeVLANs = [
        {
          PVID = "102";
        }
        {
          PVID = "3900";
        }
      ];
    };
  };

  # DHCP and DNS server (kea?):
  networking.useDHCP = false;
  networking.dhcpcd.enable = false;
  services.resolved.enable = false;

  services.dnsmasq = {
    enable = true;
    # https://wiki.archlinux.org/title/Dnsmasq
    settings = {
      interface = [
        "lo"
        ports.lan
      ];
      bind-interfaces = true;
      cache-size = "10000";

      no-resolv = true;
      # TODO: The pppd will try to write the file, which is not allowed in NixOS (readonly /etc).
      # resolv-file = "/etc/ppp/resolv.conf";
      server = [
        "223.5.5.5"
        "119.29.29.29"
      ];

      dhcp-option = [
        "1,255.0.0.0"
        "3,10.0.0.1"
        "6,10.0.0.1"
      ];
      dhcp-range = [
        "10.254.0.1,10.254.254.254,42m"
        "::,constructor:pppoe-wan,42m"
      ];
      dhcp-host = [ ];
    };
  };

  # Unsafe network:

  # NAT + Firewall with nftables.
  # @see nixpkgs/nixos/modules/services/networking/nat-nftables.nix)
  # nix eval --raw ".#nixosConfigurations.rout.config.networking.nftables.tables"
  networking.nftables.enable = true;

  networking.nat = {
    enable = true;
    internalInterfaces = [ ports.lan ];
    externalInterface = ports.wan;
  };

  networking.firewall.allowedUDPPorts = [
    53 # DNS
    67 # DHCP
  ];
}
