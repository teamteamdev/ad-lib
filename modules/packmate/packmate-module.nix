{ config, lib, pkgs, ... }@args:

with lib;

let
  cfg = config.adLib.packmate;

  packmateJar = pkgs.copyPathToStore ./packmate.jar;

  args = [
    "${pkgs.openjdk14}/bin/java"
    "-Xmx1g"
    "-jar"
    "${packmateJar}"
    "--spring.datasource.url=jdbc:postgresql:${cfg.database}"
    "--spring.datasource.username=${cfg.databaseUser}"
    "--spring.datasource.password=${cfg.databasePassword}"
    "--capture-mode=LIVE"
    "--interface-name=${cfg.interface}"
    "--local-ip=${cfg.localIp}"
    "--account-login=${cfg.login}"
    "--account-password=${cfg.password}"
    "--server.port=${toString cfg.port}"
    "--server.address=${cfg.address}"
  ];

  dropScript = pkgs.substituteAll {
    src = ./drop-older.sql;
    olderThan = cfg.dropOlderThan;
  };

  serviceSubmodule = {
    options = {
      port = mkOption {
        type = types.int;
        description = "Service port.";
      };

      decryptTls = mkOption {
        type = types.bool;
        default = false;
        description = "Decrypt TLS.";
      };

      mergeAdjacentPackets = mkOption {
        type = types.bool;
        default = false;
        description = "Decrypt TLS.";
      };

      parseWebSockets = mkOption {
        type = types.bool;
        default = false;
        description = "Parse WebSockets.";
      };

      processChunkedEncoding = mkOption {
        type = types.bool;
        default = false;
        description = "Process chunked encoding.";
      };

      ungzipHttp = mkOption {
        type = types.bool;
        default = false;
        description = "Un-gzip HTTP.";
      };

      urldecodeHttpRequests = mkOption {
        type = types.bool;
        default = false;
        description = "Decode URLs in HTTP requests.";
      };
    };
  };

in {
  options = {
    adLib.packmate = {
      enable = mkEnableOption "Packmate";

      database = mkOption {
        type = types.str;
        default = "packmate";
        description = "Packmate database.";
      };

      databaseUser = mkOption {
        type = types.str;
        default = "packmate";
        description = "Packmate database user.";
      };

      databasePassword = mkOption {
        type = types.str;
        default = "packmate";
        description = "Packmate database password";
      };

      interface = mkOption {
        type = types.str;
        description = "Packmate interface.";
      };

      localIp = mkOption {
        type = types.str;
        description = "Packmate local IP.";
      };

      login = mkOption {
        type = types.str;
        default = "user";
        description = "Packmate UI login.";
      };

      password = mkOption {
        type = types.str;
        default = "";
        description = "Packmate UI password.";
      };

      port = mkOption {
        type = types.int;
        default = 65000;
        description = "Packmate UI port.";
      };

      address = mkOption {
        type = types.str;
        default = "0.0.0.0";
        description = "Packmate UI address.";
      };

      dropOlderThan = mkOption {
        type = types.nullOr types.int;
        default = 60 * 60 * 24;
        description = "Drop packets older than this time in seconds from the database.";
      };

      initialServices = mkOption {
        type = types.attrsOf (types.submodule serviceSubmodule);
        default = {};
        description = "Initial services.";
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.services.packmate = {
      description = "Packmate traffic sniffer.";
      wantedBy = [ "multi-user.target" ];
      wants = [ "postgresql.service" ];
      after = [ "network-online.target" "postgresql.service" ];
      environment.LD_LIBRARY_PATH = makeLibraryPath [ pkgs.libpcap ];
      serviceConfig = {
        ExecStart = concatMapStringsSep " " escapeShellArg args;
        DynamicUser = true;
        CapabilityBoundingSet = [ "CAP_NET_RAW" ];
        AmbientCapabilities = [ "CAP_NET_RAW" ];
        TimeoutStopSec = 5; # Fails to stop properly after SIGTERM.
        CPUQuota = "100%"; # Hungry for CPU!
      };
    };

    systemd.services.packmate-drop-older = mkIf (cfg.dropOlderThan != null) {
      description = "Drop old Packmate packets from the database.";
      after = [ "postgresql.service" ];
      environment = {
        PGHOST = "127.0.0.1";
        PGUSER = cfg.databaseUser;
        PGPASSWORD = cfg.databasePassword;
        PGDATABASE = cfg.database;
      };
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${config.services.postgresql.package}/bin/psql -f ${dropScript}";
        DynamicUser = true;
      };
    };

    systemd.timers.packmate-drop-older = mkIf (cfg.dropOlderThan != null) {
      description = "Drop old Packmate packets from the database.";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnActiveSec = "10min";
        OnUnitActiveSec = "10min";
      };
    };
  };
}
