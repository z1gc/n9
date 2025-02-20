# 10.0.0.1 => Router
# 10.254.0.0 => DHCP
# 10.29.0.0 => PXE (later)
# 10.42.0.0 => Proxy
# May conflicts with?

{ lib, pkgs, ... }:

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

  mkBridgeSlave =
    port: master:
    lib.recursiveUpdate (
      mkNetwork port {
        networkConfig.Bridge = master;
        linkConfig.RequiredForOnline = "enslaved";
      }
    );

  # Y-AXIS
  domain = "y.xas.is";
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

    "20-lan" = {
      netdevConfig = {
        Kind = "bridge";
        Name = ports.lan;
      };
    };
  };

  # PPPoE (netdev), networkd managed as well:
  boot.kernelModules = [ "pppoe" ];

  services.pppd = {
    enable = true;
    # https://man7.org/linux/man-pages/man8/pppd.8.html
    peers.wan.config = ''
      plugin pppoe.so
      ifname ${ports.wan}
      nic-${ports.vlan}
      file /etc/ppp/secrets/wan

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
    "10-sfp-0" = mkNetwork ports.sfp-0 {
      vlan = [ ports.vlan ];
      networkConfig.Address = "192.168.1.10/32";
    };
    "11-vlan" = mkNetwork ports.vlan { };

    "20-wan" = mkNetwork ports.wan {
      # https://wiki.debian.org/IPv6PrefixDelegation
      networkConfig = {
        DHCP = "ipv6";
        DefaultRouteOnDevice = "yes";
        KeepConfiguration = "static";
        LinkLocalAddressing = "ipv6";
      };
      dhcpV6Config = {
        PrefixDelegationHint = "::/60";
        WithoutRA = "solicit";
        UseDNS = "no";
        UseHostname = "no";
      };
      linkConfig.RequiredForOnline = "yes"; # TODO: Is it really working?
    };

    "30-rj45-0" = mkBridgeSlave ports.rj45-0 ports.lan { };
    "31-rj45-1" = mkBridgeSlave ports.rj45-1 ports.lan { };
    "32-rj45-2" = mkBridgeSlave ports.rj45-2 ports.lan { };
    "33-lan" = mkNetwork ports.lan {
      networkConfig = {
        Address = "10.0.0.1/8";
        IPv6SendRA = "yes";
        IPv6AcceptRA = "no";
        DHCPPrefixDelegation = "yes";
        LinkLocalAddressing = "ipv6";
      };
      ipv6SendRAConfig = {
        Managed = "yes";
        OtherInformation = "yes";
      };
      dhcpPrefixDelegationConfig.Token = "::1";
    };
  };

  # The `networking.firewall.filterForward = true` is conflicted, and has no
  # such customization options. TODO: How to make one?
  # https://github.com/LostAttractor/Router/blob/master/configuration/network/nftables.nix
  networking.nftables.tables."mss-clamping" = {
    family = "inet";
    content = ''
      chain forward {
        type filter hook forward priority filter; policy accept;
        tcp flags syn tcp option maxseg size set rt mtu
      }
    '';
  };

  # Relavents:
  services.networkd-dispatcher = {
    enable = true;
    rules."restart-dnsmasq" = {
      onState = [ "routable" ];
      script = ''
        #!${pkgs.runtimeShell}
        if [[ "$IFACE" == "${ports.wan}" && "$AdministrativeState" == "configured" ]]; then
          systemctl restart dnsmasq
        fi
        exit 0
      '';
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
      bind-dynamic = true;
      cache-size = "10000";
      enable-ra = true;

      resolv-file = "/run/pppd/resolv.conf";
      server = [
        "223.5.5.5"
        "119.29.29.29"
      ];

      dhcp-authoritative = true;
      dhcp-option = [
        "1,255.0.0.0"
        "3,10.0.0.1"
        "6,10.0.0.1"
      ];
      dhcp-range = [
        "10.254.0.1,10.254.254.254,72h"
        "::,constructor:${ports.wan},slaac,ra-stateless,ra-names,72h"
      ];
      dhcp-host = [
        # @see /var/lib/dnsmasq/dnsmasq.leases
        "24:5e:be:87:47:cc,10.254.38.179" # snap
      ];

      inherit domain;
      local = "/${domain}/"; # only resolve in local, don't go out
      address = [ "/wa.${domain}/10.0.0.1" ];
    };
  };

  # Unsafe network:

  # NAT + Firewall with nftables.
  # @see nixpkgs/nixos/modules/services/networking/nat-nftables.nix)
  # nix eval --raw ".#nixosConfigurations.rout.config.networking.nftables.tables"
  networking.nftables.enable = true;

  networking.nat = {
    enable = true;
    enableIPv6 = true;
    internalInterfaces = [ ports.lan ];
    externalInterface = ports.wan;
  };

  networking.firewall.allowedUDPPorts = [
    53 # DNS
    67 # DHCP
  ];
}
