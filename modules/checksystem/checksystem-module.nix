{ config, lib, pkgs, ... }:

with import ../lib.nix { inherit lib; };

let
  checksystem = pkgs.perlPackages.callPackage ./checksystem.nix { };

  cfg = config.adLib.checksystem;

  configTemplate = pkgs.writeText "checksystem.conf.template" (toPerl csConfig);

  csConfig = {
    hypnotoad = {
      listen = cfg.listen;
      workers = cfg.frontendWorkers;
      pid_file = "/tmp/hypnotoad.pid";
    };
    pg.uri = cfg.postgresqlUrl;
    cs = {
      base_url = cfg.baseUrl;
      time = map (time: [time.from time.to]) cfg.times;
      admin.auth = "${cfg.adminUser}:_adminPassword_";
      ctf.name = cfg.name;
      round_length = cfg.roundLength;
      flag_life_time = cfg.flagLifeTime;
      flags.secret = "_secret_";
    };
    teams = mapAttrsToList (host: opts: ({
       inherit (opts) name network;
       inherit host;
       token = "_${host}Token_";
    } // optionalAttrs (opts.logo != null) { inherit (opts) logo; })) cfg.teams;
    services = mapAttrsToList (name: opts: ({
      inherit (opts) path timeout;
      inherit name;
    } // optionalAttrs (opts.tcpPort != null) { tcp_port = opts.tcpPort; })) cfg.services;
  };

  csWrapper = pkgs.writeScriptBin "cs" ''
    #!${pkgs.stdenv.shell}
    export MOJO_CONFIG=/var/lib/checksystem/c_s.conf
    exec ${checksystem}/bin/cs "$@"
  '';

  timeSubmodule = {
    options = {
      from = mkOption {
        type = types.str;
        description = "Starting time.";
      };

      to = mkOption {
        type = types.str;
        description = "Ending time.";
      };
    };
  };

  teamSubmodule = {
    options = {
      name = mkOption {
        type = types.str;
        description = "Team name.";
      };

      network = mkOption {
        type = types.str;
        description = "Team network.";
      };

      logo = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Path to logo.";
      };
    };
  };

  serviceSubmodule = {
    options = {
      path = mkOption {
        type = types.path;
        description = "Service path.";
      };

      timeout = mkOption {
        type = types.int;
        default = 1;
        description = "Service timeout.";
      };

      tcpPort = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Service timeout.";
      };
    };
  };

in {
  options = {
    adLib.checksystem = {
      enable = mkEnableOption "checksystem";

      listen = mkOption {
        type = types.listOf types.str;
        default = ["http://127.0.0.1:8080"];
        description = "Addresses to listen on.";
      };

      frontendWorkers = mkOption {
        type = types.int;
        default = 8;
        description = "Number of frontend workers.";
      };

      workers = mkOption {
        type = types.int;
        default = 3;
        description = "Number of backend workers.";
      };

      checkerWorkers = mkOption {
        type = types.int;
        default = 48;
        description = "Number of checker workers.";
      };

      postgresqlUrl = mkOption {
        type = types.str;
        default = "postgresql:///checksystem";
        description = "PostgreSQL database URL.";
      };

      baseUrl = mkOption {
        type = types.str;
        description = "Base URL.";
      };

      times = mkOption {
        type = types.listOf (types.submodule timeSubmodule);
        description = "Event times.";
      };

      adminUser = mkOption {
        type = types.str;
        default = "admin";
        description = "Admin user.";
      };

      name = mkOption {
        type = types.str;
        description = "Event name.";
      };

      roundLength = mkOption {
        type = types.int;
        default = 8;
        description = "Round length.";
      };

      flagLifeTime = mkOption {
        type = types.int;
        default = 15;
        description = "Flag life time.";
      };

      teams = mkOption {
        type = types.attrsOf (types.submodule teamSubmodule);
        default = {};
        description = "Teams.";
      };

      services = mkOption {
        type = types.attrsOf (types.submodule serviceSubmodule);
        default = {};
        description = "Event services.";
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.services."checksystem-frontend" = {
      wantedBy = [ "multi-user.target" ];
      after = [ "checksystem-init.service" ];
      restartTriggers = [ configTemplate ];
      environment."MOJO_CONFIG" = "/var/lib/checksystem/c_s.conf";
      serviceConfig = {
        Type = "forking";
        ExecStart = "${checksystem}/bin/hypnotoad-cs";
        ExecStop = "${checksystem}/bin/hypnotoad-cs -s";
        PrivateTmp = true;
        StateDirectory = "checksystem";
        StateDirectoryMode = "0700";
        User = "checksystem";
        Group = "nobody";
      };
    };

    systemd.services."checksystem-manager" = {
      wantedBy = [ "multi-user.target" ];
      after = [ "checksystem-init.service" ];
      restartTriggers = [ configTemplate ];
      environment."MOJO_CONFIG" = "/var/lib/checksystem/c_s.conf";
      serviceConfig = {
        ExecStart = "${checksystem}/bin/cs manager";
        StateDirectory = "checksystem";
        StateDirectoryMode = "0700";
        User = "checksystem";
        Group = "nobody";
      };
    };

    systemd.services."checksystem-watcher" = {
      wantedBy = [ "multi-user.target" ];
      after = [ "checksystem-init.service" ];
      restartTriggers = [ configTemplate ];
      environment."MOJO_CONFIG" = "/var/lib/checksystem/c_s.conf";
      serviceConfig = {
        ExecStart = "${checksystem}/bin/cs watcher";
        StateDirectory = "checksystem";
        StateDirectoryMode = "0700";
        User = "checksystem";
        Group = "nobody";
      };
    };

    systemd.services."checksystem-worker" = {
      wantedBy = [ "multi-user.target" ];
      after = [ "checksystem-init.service" ];
      restartTriggers = [ configTemplate ];
      environment."MOJO_CONFIG" = "/var/lib/checksystem/c_s.conf";
      serviceConfig = {
        ExecStart = "${checksystem}/bin/cs minion worker -j ${toString cfg.workers}";
        StateDirectory = "checksystem";
        StateDirectoryMode = "0700";
        User = "checksystem";
        Group = "nobody";
      };
    };

    systemd.services."checksystem-checker-worker" = {
      wantedBy = [ "multi-user.target" ];
      after = [ "checksystem-init.service" ];
      restartTriggers = [ configTemplate ];
      environment."MOJO_CONFIG" = "/var/lib/checksystem/c_s.conf";
      serviceConfig = {
        ExecStart = "${checksystem}/bin/cs minion worker -q checker -j ${toString cfg.checkerWorkers}";
        StateDirectory = "checksystem";
        StateDirectoryMode = "0700";
        User = "checksystem";
        Group = "nobody";
      };
    };

    systemd.services."checksystem-init" = {
      wantedBy = [ "multi-user.target" ];
      wants = [ "postgresql.service" ];
      after = [ "postgresql.service" ];
      environment."MOJO_CONFIG" = "/var/lib/checksystem/c_s.conf";
      serviceConfig = {
        Type = "oneshot";
        User = "checksystem";
        StateDirectory = "checksystem";
        StateDirectoryMode = "0700";
        WorkingDirectory = "/var/lib/checksystem";
        Group = "nobody";
      };
      script = ''
        if [ ! -e admin-password ]; then
          cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 16 > admin-password
        fi
        if [ ! -e secret ]; then
          cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 16 > secret
        fi
        mkdir -p teams
        ${concatStringsSep "\n" (mapAttrsToList (host: opts: ''
          if [ ! -e "teams/${host}-token" ]; then
            cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 32 > "teams/${host}-token"
          fi
        '') cfg.teams)}
        sed ${configTemplate} \
          -e "s,_secret_,$(cat secret),g" \
          -e "s,_adminPassword_,$(cat admin-password),g" \
          ${concatStringsSep " " (mapAttrsToList (host: opts: ''-e "s,_${host}Token_,$(cat "teams/${host}-token"),g"'') cfg.teams)} \
          > c_s.conf
        if [ ! -f init ]; then
          ${checksystem}/bin/cs init_db
          touch init
        fi
      '';
    };

    environment.systemPackages = [ csWrapper ];

    users.extraUsers.checksystem = {
      home = "/var/lib/checksystem";
    };
  };
}
