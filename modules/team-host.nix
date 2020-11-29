{ lib, pkgs, config, nodes, name, ... }@args:

with import ./lib.nix { inherit lib; };

let
  cfg = config.adLib.teamHost;

  otherTeamNodes = filterAttrs (name: machine: name != args.name && machine.config.adLib.teamHost.enable) nodes;
  otherTeams = mapAttrsToList (name: machine: {
    name = machine.config.adLib.teamHost.name;
    value = machine.config.adLib.p2pTunnels.ipAddress;
  }) otherTeamNodes;

  inherit (config.adLib.teamNetwork) vpnSubnet;
  vpnHost = concatStringsSep "." (take 3 (splitString "." vpnSubnet) ++ ["1"]);

  juryConfigs = mapAttrsToList (name: machine: machine.config) (filterAttrs (name: machine: machine.config.adLib.juryHost.enable) nodes);
  juryConfig =
    if length juryConfigs == 1 then head juryConfigs else throw "Jury host not found in configuration, or there are too many of them";

  networkAddresses = mapAttrsToList (name: machine: machine.config.adLib.p2pTunnels.ipAddress) (filterAttrs (name: machine: machine.config.adLib.p2pTunnels.enable) nodes);

  makeAddresses = map (addr: { address = addr; prefixLength = 24; });
  inwardForwardAddresses = makeAddresses (unique (map prefix24FromAddress [ config.adLib.vulnbox.hostAddress ]));
  outwardForwardAddresses = makeAddresses (unique (map prefix24FromAddress networkAddresses));

  trafficFilter = concatMapStringsSep " or " (addr: "(net ${addr.address}/${toString addr.prefixLength})") outwardForwardAddresses;

in {
  options = {
    adLib.teamHost = {
      enable = mkEnableOption "team host";

      name = mkOption {
        type = types.str;
        description = "Team name";
      };

      logo = mkOption {
        type = types.nullOr types.str;
        description = "Team logo";
      };
    };
  };

  config = mkIf cfg.enable {
    adLib.p2pTunnels = {
      enable = true;
      allowedForwardAddresses = inwardForwardAddresses;
    };

    adLib.trafficDump = {
      enable = true;
      filter = trafficFilter;
    };

    services.postgresql = {
      enable = true;
      ensureDatabases = [ "packmate" ];
      ensureUsers = [
        { name = "packmate";
          ensurePermissions = { "DATABASE packmate" = "ALL PRIVILEGES"; };
        }
      ];
    };
    systemd.services.postgresql.postStart = mkAfter ''
      $PSQL -tAc "ALTER USER packmate PASSWORD 'packmate'"
    '';

    networking.nat.extraCommands = ''
      iptables -A adlib-forward -o teambr0 -p tcp --dport 22 ! -s ${vpnSubnet}/24 -j DROP
    '';

    adLib.teamNetwork = {
      enable = true;
      allowedForwardAddresses = inwardForwardAddresses ++ outwardForwardAddresses;
    };

    adLib.vulnbox = {
      enable = true;
      netmask = "255.255.255.0";
      allowedForwardAddresses = outwardForwardAddresses;
    };
    # Shit happens.
    systemd.services.libvirtd.serviceConfig.OOMScoreAdjust = -150;

    adLib.packmate = {
      enable = true;
      interface = "teambr0";
      localIp = config.adLib.vulnbox.guestAddress;
      address = "127.0.0.1";
    };
    systemd.services.packmate.after = [ "team-vulnbox.service" ];

    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      virtualHosts."packmate" = {
        listen = singleton {
          addr = vpnHost;
          port = 31337;
        };
        locations."/" = {
          proxyPass = "http://127.0.0.1:65000";
          proxyWebsockets = true;
          # Authentiate automatically.
          extraConfig = ''
            proxy_set_header Authorization "Basic dXNlcjo=";
          '';
        };
      };
      virtualHosts."destructive-farm" = {
        listen = singleton {
          addr = vpnHost;
          port = 31338;
        };
        locations."/".extraConfig = ''
          uwsgi_pass unix:/run/uwsgi/destructive-farm.sock;
          include ${pkgs.nginx}/conf/uwsgi_params;
          uwsgi_param HTTP_AUTHORIZATION "Basic dXNlcjo=";
        '';
      };
    };

    users.extraUsers.nginx.extraGroups = [ "uwsgi" ];

    adLib.destructiveFarm = {
      enable = true;
      teams = listToAttrs otherTeams;
      protocol = "ructf_http";
      flagLifeTime = juryConfig.adLib.checksystem.flagLifeTime;
      extraConfig = {
        "SYSTEM_URL" = "http://${juryConfig.adLib.p2pTunnels.ipAddress}/flags";
        "SYSTEM_TOKEN" = "@token@";
      };
    };
    systemd.services.destructive-farm-submit.preStart = mkAfter ''
      sed -i "s,@token@,$(cat /var/lib/destructive-farm/token),g" config.json
    '';

    services.prometheus.exporters.node = {
      enable = true;
      enabledCollectors = [ "systemd" ];
      disabledCollectors = [ "textfile" ];
    };

    networking.firewall.extraCommands = ''
      iptables -A nixos-fw -s ${vpnSubnet}/24 -p tcp --dport 31337 -j nixos-fw-accept
      iptables -A nixos-fw -s ${vpnSubnet}/24 -p tcp --dport 31338 -j nixos-fw-accept
      iptables -A nixos-fw -s ${juryConfig.adLib.internalIp} -p tcp -m tcp --dport 9100 -m comment --comment node-exporter -j nixos-fw-accept
    '';
  };
}
