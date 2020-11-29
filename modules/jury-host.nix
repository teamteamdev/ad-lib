{ config, lib, name, nodes, ... }:

with import ./lib.nix { inherit lib; };

let
  cfg = config.adLib.juryHost;

  ipAddress = config.adLib.p2pTunnels.ipAddress;

  teamNodes = filterAttrs (name: machine: machine.config.adLib.teamHost.enable) nodes;
  teams = mapAttrs' (name: machine: nameValuePair machine.config.adLib.p2pTunnels.ipAddress {
    inherit (machine.config.adLib.teamHost) name logo;
    network = "${machine.config.adLib.p2pTunnels.ipAddress}/32";
  }) teamNodes;

  outwardForwardAddresses = map prefix24FromAddress (attrNames teams);
  trafficFilter = concatMapStringsSep " or " (addr: "(net ${addr}/24)") outwardForwardAddresses;

in {
  options = {
    adLib.juryHost = {
      enable = mkEnableOption "jury host";

      hostName = mkOption {
        type = types.str;
        description = "External host name.";
      };
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ 80 443 ];

    adLib.p2pTunnels = {
      enable = true;
      assignLocal = true;
      forceNoLimit = true;
   };

    adLib.trafficDump = {
      enable = true;
      filter = trafficFilter;
    };

    adLib.checksystem = {
      enable = true;
      listen = [ "http://127.0.0.1:31337" ];
      baseUrl = "https://${cfg.hostName}";
      inherit teams;
    };

    services.postgresql = {
      enable = true;
      ensureDatabases = [ "checksystem" ];
      ensureUsers = [
        { name = "checksystem";
          ensurePermissions = { "DATABASE checksystem" = "ALL PRIVILEGES"; };
        }
      ];
      identMap = ''
        users checksystem checksystem
      '';
    };

    services.prometheus = {
      enable = true;
      scrapeConfigs = [
        { job_name = "prometheus";
          static_configs = [
            { targets = [ "127.0.0.1:9090" ];
              labels = { instance = name; };
            }
          ];
        }
        { job_name = "node";
          static_configs = [
            { targets = [ "127.0.0.1:9100" ];
              labels = { instance = name; };
            }
          ] ++ mapAttrsToList (name: machine: {
            targets = [ "${machine.config.adLib.internalIp}:9100" ];
            labels = { instance = name; };
          }) teamNodes;
        }
      ];
    };
    services.prometheus.exporters.node = {
      enable = true;
      enabledCollectors = [ "systemd" ];
      disabledCollectors = [ "textfile" ];
    };

    services.grafana = {
      enable = true;
      provision.datasources = [
        { name = "Prometheus";
          type = "prometheus";
          url = "http://localhost:9090";
        }
      ];
    };

    security.acme.acceptTerms = true;

    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      virtualHosts."${cfg.hostName}" = {
        addSSL = true;
        enableACME = true;
        default = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:31337";
          proxyWebsockets = true;
        };
      };
    };
  };
}
