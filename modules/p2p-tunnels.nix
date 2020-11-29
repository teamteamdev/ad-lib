{ config, lib, pkgs, nodes, name, ... }@args:

with lib;

let
  cfg = config.adLib.p2pTunnels;

  otherHosts = filterAttrs (name: machine: name != args.name && machine.config.adLib.p2pTunnels.enable) nodes;
  otherNodes = imap0 (i: tun: tun // { dev = "teamgre${toString i}"; }) (mapAttrsToList (name: machine: {
    inherit name machine;
    external = machine.config.adLib.internalIp;
    internal = machine.config.adLib.p2pTunnels.ipAddress;
    port = machine.config.adLib.p2pTunnels.fouPort;
    forceNoLimit = machine.config.adLib.p2pTunnels.forceNoLimit;
  }) otherHosts);

  addressOptions = {
    options = {
      address = mkOption {
        type = types.str;
        description = "IP address.";
      };

      prefixLength = mkOption {
        type = types.int;
        default = 32;
        description = "IP prefix length.";
      };
    };
  };

  stopTunnels = pkgs.writeScript "stop-tunnels" ''
    #!${pkgs.stdenv.shell}

    ${concatMapStringsSep "\n" (tun: ''
      ip link del name ${tun.dev} 2>/dev/null
    '') otherNodes}
    ip fou del port ${toString cfg.fouPort} local ${config.adLib.internalIp} 2>/dev/null
    exit 0
  '';

in {
  options = {
    adLib.p2pTunnels = {
      enable = mkEnableOption "P2P tunnels";

      fouPort = mkOption {
        type = types.int;
        default = 5555;
        description = "FOU port for A/D traffic encapsulation.";
      };

      ipAddress = mkOption {
        type = types.str;
        description = "IP address for the local tunnel endpoint.";
      };

      assignLocal = mkOption {
        type = types.bool;
        default = false;
        description = "Assign local IP address to all tunnels.";
      };

      allowedForwardAddresses = mkOption {
        type = types.listOf (types.submodule addressOptions);
        default = [];
        description = "IP addresses which are allowed to be forwarded to.";
      };

      uploadLimit = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Outbound traffic limit.";
      };

      forceNoLimit = mkOption {
        type = types.bool;
        default = false;
        description = "Force-disable traffic shaping for this peer.";
      };
    };
  };

  config = mkIf cfg.enable {
    adLib.internalFirewall.allowedUDPPorts = [ cfg.fouPort ];

    networking.nat.extraCommands = mkIf config.networking.nat.enable (concatMapStringsSep "\n" (tun: ''
      # ${tun.dev}
      ${concatMapStringsSep "\n" (addr: ''
        iptables -A adlib-forward -i ${tun.dev} -s ${tun.internal} -d ${addr.address}/${toString addr.prefixLength} -j ACCEPT
      '') cfg.allowedForwardAddresses}
      iptables -A adlib-forward -i ${tun.dev} -j DROP
      iptables -t nat -A nixos-nat-post -o ${tun.dev} -j SNAT --to ${cfg.ipAddress}
    '') otherNodes);

    systemd.services.p2p-tunnels = {
      description = "Set up P2P tunnels.";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      path = [ pkgs.iproute pkgs.kmod ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStop = stopTunnels;
      };
      script = ''
        # Needed because dhcpcd forks before waiting for _all_ interfaces to get an IP. Should be fine...
        sleep 1

        set -x
        modprobe fou gre
        ${stopTunnels}
        ip fou add port ${toString cfg.fouPort} ipproto 47 local ${config.adLib.internalIp}
        ${concatMapStringsSep "\n" (tun: ''
          ip link add name ${tun.dev} type gre remote ${tun.external} local ${config.adLib.internalIp} ttl 225 encap fou encap-sport auto encap-dport ${toString tun.port}
          ${optionalString cfg.assignLocal ''
            ip addr add ${cfg.ipAddress}/32 dev ${tun.dev}
          ''}
          ${optionalString (cfg.uploadLimit != null && !tun.forceNoLimit) ''
            tc qdisc add dev ${tun.dev} root tbf rate ${toString cfg.uploadLimit}kbit latency 50ms burst 50kb
          ''}
          ip link set dev ${tun.dev} up
          ip route add ${tun.internal}/32 dev ${tun.dev}
        '') otherNodes}
      '';
    };
  };
}
