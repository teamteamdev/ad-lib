{ config, lib, ... }:

with lib;

{
  config = mkIf config.networking.nat.enable {
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
  };
}
