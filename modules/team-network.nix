{ config, lib, pkgs, nodes, name, ... }@args:

with import ./lib.nix { inherit lib; };

let
  cfg = config.adLib.teamNetwork;

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

in {
  options = {
    adLib.teamNetwork = {
      enable = mkEnableOption "A/D team network";

      vpnSubnet = mkOption {
        type = types.str;
        description = "OpenVPN server /24 subnet.";
      };

      vpnPort = mkOption {
        type = types.int;
        default = 1194;
        description = "OpenVPN server port.";
      };

      allowedForwardAddresses = mkOption {
        type = types.listOf (types.submodule addressOptions);
        default = [];
        description = "IP addresses which are allowed to be forwarded to.";
      };
    };
  };

  config = mkIf cfg.enable {
    adLib.p2pTunnels = {
      enable = true;
      assignLocal = false;
    };

    networking.firewall.allowedUDPPorts = [ cfg.vpnPort ];

    networking.nat = {
      enable = true;
      extraCommands = ''
        # tun0
        ${concatMapStringsSep "\n" (addr: ''
          iptables -A adlib-forward -i tun0 -d ${addr.address}/${toString addr.prefixLength} -j ACCEPT
        '') cfg.allowedForwardAddresses}
        iptables -A adlib-forward -i tun0 -j DROP
      '';
    };

    # Needed for `local` to work.
    systemd.services.openvpn-team-network.after = [ "network-online.target" "team-network-generate-keys.service" ];
    systemd.services.openvpn-team-network.wants = [ "team-network-generate-keys.service" ];

    systemd.services.team-network-generate-keys = {
      path = [ pkgs.easyrsa pkgs.gawk ];
      serviceConfig = {
        Type = "oneshot";
        StateDirectory = "team-network";
        StateDirectoryMode = "0700";
        WorkingDirectory = "/var/lib/team-network";
      };
      script = ''
        if [ -e pki/serial ]; then
          echo "Certificates already generated"
          exit 0
        fi

        easyrsa --batch init-pki
        easyrsa --batch gen-dh
        easyrsa --batch build-ca nopass
        easyrsa --batch build-server-full server nopass
        easyrsa --batch build-client-full client nopass
      '';
    };

    services.openvpn.servers.team-network = {
      config = ''
        dev tun0
        local ${config.adLib.externalIp}
        dev-type tun
        tls-server
        port ${toString cfg.vpnPort}
        server ${cfg.vpnSubnet} 255.255.255.0
        ca /var/lib/team-network/pki/ca.crt
        cert /var/lib/team-network/pki/issued/server.crt
        key /var/lib/team-network/pki/private/server.key
        dh /var/lib/team-network/pki/dh.pem
        remote-cert-tls client
        persist-tun
        persist-key
        duplicate-cn
        client-to-client
        keepalive 10 60
        ${concatMapStringsSep "\n" (addr: ''
          push "route ${addr.address} ${prefixLengthToMask addr.prefixLength}"
        '') cfg.allowedForwardAddresses}
      '';
    };
  };
}
