{ config, lib, pkgs, ... }:

with lib;

let
  destructiveFarm = pkgs.python3.pkgs.callPackage ./destructive-farm.nix { };

  cfg = config.adLib.destructiveFarm;

  configFile = pkgs.writeText "destructive_farm_config.py" ''
    import json

    with open("/var/lib/destructive-farm/config.json") as r:
      CONFIG = json.load(r)
  '';

  dfConfig = pkgs.writeText "destructive_farm_config.json" (builtins.toJSON ({
    "TEAMS" = cfg.teams;
    "FLAG_FORMAT" = cfg.flagFormat;
    "SYSTEM_PROTOCOL" = cfg.protocol;
    "SUBMIT_FLAG_LIMIT" = cfg.submitFlagLimit;
    "SUBMIT_PERIOD" = cfg.submitPeriod;
    "FLAG_LIFETIME" = cfg.flagLifeTime;
    "SERVER_PASSWORD" = "";
    "ENABLE_API_AUTH" = false;
    "API_TOKEN" = "";
  } // cfg.extraConfig));

in {
  options = {
    adLib.destructiveFarm = {
      enable = mkEnableOption "DestructiveFarm";

      extraConfig = mkOption {
        type = types.attrs;
        default = {};
        description = "Configuration variables.";
      };

      flagFormat = mkOption {
        type = types.str;
        default = "[A-Z0-9]{31}=";
        description = "Flag format.";
      };

      teams = mkOption {
        type = types.attrsOf types.str;
        description = "Teams, as a map from names to IP addresses.";
      };

      submitFlagLimit = mkOption {
        type = types.int;
        default = 50;
        description = "Flag submit limit.";
      };

      submitPeriod = mkOption {
        type = types.int;
        default = 1;
        description = "Flag submit period.";
      };

      flagLifeTime = mkOption {
        type = types.int;
        default = 5 * 60;
        description = "Flag life time.";
      };

      protocol = mkOption {
        type = types.str;
        default = "ructf_tcp";
        description = "Checksystem protocol.";
      };
    };
  };

  config = mkIf cfg.enable {
    services.uwsgi = {
      enable = true;
      plugins = [ "python3" ];
      user = "root"; # Needed to spawn vassals as different users.
      group = "uwsgi";
      instance = {
        type = "emperor";
        vassals = {
          destructive-farm = {
            type = "normal";
            plugins = [ "python3" ];
            pythonPackages = pkgs: [ destructiveFarm ];
            env = [
              "FLAGS_DATABASE=/var/lib/destructive-farm/db.sqlite"
              "CONFIG=${configFile}"
            ];
            socket = "/run/uwsgi/destructive-farm.sock";
            chdir = "/var/lib/destructive-farm";
            chmod-socket = 664;
            uid = "destructive-farm";
            gid = "uwsgi";
            logger = "syslog:destructive-farm";
            module = "server";
            callable = "app";
          };
        };
      };
    };

    systemd.services."uwsgi" = {
      after = [ "destructive-farm-submit.service" ];
      restartTriggers = [ dfConfig ];

      serviceConfig = {
        User = "root";
        Group = "uwsgi";
        RuntimeDirectory = "uwsgi";
        RuntimeDirectoryMode = "0775";
      };
    };

    systemd.services."destructive-farm-submit" = {
      wantedBy = [ "multi-user.target" ];
      environment = {
        "FLAGS_DATABASE" = "/var/lib/destructive-farm/db.sqlite";
        "CONFIG" = configFile;
      };
      restartTriggers = [ dfConfig ];
      serviceConfig = {
        ExecStart = "${destructiveFarm}/bin/submit_loop";
        User = "destructive-farm";
        Group = "nobody";
        StateDirectory = "destructive-farm";
        StateDirectoryMode = "0700";
        WorkingDirectory = "/var/lib/destructive-farm";
      };
      preStart = ''
        cat ${dfConfig} > config.json
      '';
    };

    users.extraUsers.destructive-farm = {
      group = "uwsgi";
      home = "/var/lib/destructive-farm";
    };
  };
}
