{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.adLib.trafficDump;
  args = concatMapStringsSep " " escapeShellArg ([
    "${pkgs.tcpdump}/bin/tcpdump"
    "-w"
    "/var/lib/traffic-dump/dump-%%F-%%T.pcap"
    "-K"
    "-n"
    "-z" "gzip"
    "-i" cfg.interface
  ] ++ optionals (cfg.rotateSecs != null) ["-G" (toString cfg.rotateSecs)]
    ++ optional (cfg.filter != null) cfg.filter);

  packRemaining = pkgs.writeScript "traffic-dump-stop" ''
    #!${pkgs.stdenv.shell}
    if ls /var/lib/traffic-dump/*.pcap >/dev/null 2>&1; then
      gzip /var/lib/traffic-dump/*.pcap
    fi
  '';

in {
  options = {
    adLib.trafficDump = {
      enable = mkEnableOption "traffic dump";

      interface = mkOption {
        type = types.str;
        default = "any";
        description = ''
          Network interfaces on which to listen and dump traffic.
        '';
      };

      rotateSecs = mkOption {
        type = types.nullOr types.int;
        default = 10 * 60;
        description = ''
          Rotate dump files every N seconds.
        '';
      };

      filter = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          tcpdump filter expression.
        '';
      };

      dropOlderThan = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Delete dumps older than this number of days.";
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.services.traffic-dump = {
      description = "Dump traffic into compressed pcap files.";
      wantedBy = [ "network-online.target" ];
      after = [ "network-online.target" ];
      path = [ pkgs.gzip ];
      serviceConfig = {
        RestartSec = 5;
        Restart = "always";
        DynamicUser = true;
        StateDirectory = "traffic-dump";
        StateDirectoryMode = "0700";
        CapabilityBoundingSet = [ "CAP_NET_RAW" ];
        AmbientCapabilities = [ "CAP_NET_RAW" ];
        ExecStart = args;
        ExecStartPost = "-${packRemaining}";
      };
    };

    systemd.services.traffic-dump-drop-older = mkIf (cfg.dropOlderThan != null) {
      description = "Delete old traffic dumps.";
      path = [ pkgs.findutils ];
      serviceConfig = {
        Type = "oneshot";
        DynamicUser = true;
        StateDirectory = "traffic-dump";
        StateDirectoryMode = "0700";
        WorkingDirectory = "/var/lib/traffic-dump";
      };
      script = ''
        find -name \*.pcap.gz -mtime ${toString cfg.dropOlderThan} -type f -delete
        find -name \*.pcap -size 0 -type f -delete
      '';
    };

    systemd.timers.traffic-dump-drop-older = mkIf (cfg.dropOlderThan != null) {
      description = "Delete old traffic dumps.";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnActiveSec = "10min";
        OnUnitActiveSec = "10min";
      };
    };
  };
}
