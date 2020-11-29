{ config, lib, ... }:

with lib;
{
  options = {
    adLib.externalInterface = mkOption {
      type = types.str;
      description = "External interface, which connects to the Internet.";
    };

    adLib.internalIp = mkOption {
      type = types.str;
      description = "Internal IP address, accessible from other nodes.";
      default = config.deployment.targetHost;
    };

    adLib.externalIp = mkOption {
      type = types.str;
      description = "IP address of external interface.";
      default = config.deployment.targetHost;
    };

    adLib.internalFirewall = {
      allowedTCPPorts = mkOption {
        type = types.listOf types.int;
        default = [];
      };

      allowedUDPPorts = mkOption {
        type = types.listOf types.int;
        default = [];
      };
    };
  };

  imports = [
    ./p2p-tunnels.nix
    ./team-network.nix
    ./team-host.nix
    ./jury-host.nix
    ./firewall-forward.nix
    ./traffic-dump.nix
    ./vulnbox/vulnbox.nix
    ./packmate/packmate-module.nix
    ./destructive-farm/destructive-farm-module.nix
    ./checksystem/checksystem-module.nix
  ];

  config = {
    networking.nat = {
      extraCommands = mkMerge [
        (mkBefore ''
            iptables -F adlib-forward 2> /dev/null || true
            iptables -X adlib-forward 2> /dev/null || true
            iptables -N adlib-forward

            # Allow established.
            iptables -A adlib-forward -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
        '')
        (mkAfter ''
          iptables -A FORWARD -j adlib-forward
        '')
      ];
      extraStopCommands = mkAfter ''
        iptables -D FORWARD -j adlib-forward 2>/dev/null || true
      '';
    };

    networking.firewall.extraCommands = ''
      ${concatMapStringsSep "\n" (port: "iptables -A nixos-fw -s ${config.adLib.internalIp}/24 -p tcp --dport ${toString port} -j nixos-fw-accept") config.adLib.internalFirewall.allowedTCPPorts}
      ${concatMapStringsSep "\n" (port: "iptables -A nixos-fw -s ${config.adLib.internalIp}/24 -p udp --dport ${toString port} -j nixos-fw-accept") config.adLib.internalFirewall.allowedUDPPorts}
    '';
  };
}
