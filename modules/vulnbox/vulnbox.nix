{ config, lib, pkgs, ... }@args:

with lib;

let
  cfg = config.adLib.vulnbox;

  inherit (config.adLib.p2pTunnels) ipAddress;
  ipPrefix = concatStringsSep "." (take 3 (splitString "." ipAddress) ++ ["0"]);

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

  stopVulnbox = pkgs.writeScript "stop-vulnbox" ''
    #!${pkgs.stdenv.shell}

    if virsh shutdown vulnbox 2>/dev/null; then
      for i in $(seq 1 60); do
        if [ "$(virsh domstate vulnbox)" = "shut off" ]; then
          GOOD=1
          break
        fi
        sleep 1
      done
      if [ -z "$GOOD" ]; then
        virsh destroy vulnbox 2>/dev/null
      fi
    fi
    virsh net-destroy internal 2>/dev/null
    exit 0
  '';

in {
  options = {
    adLib.vulnbox = {
      enable = mkEnableOption "Vulnbox";

      image = mkOption {
        type = types.path;
        description = "Vulnbox image in qcow2.gz format.";
      };

      hostAddress = mkOption {
        type = types.str;
        description = "Vulnbox network' host address";
      };

      netmask = mkOption {
        type = types.str;
        description = "Vulnbox network' host netmask";
      };

      guestAddress = mkOption {
        type = types.str;
        description = "Vulnbox network' guest netmask";
      };

      allowedForwardAddresses = mkOption {
        type = types.listOf (types.submodule addressOptions);
        default = [];
        description = "IP addresses which are allowed to be forwarded to.";
      };
    };
  };

  config = mkIf cfg.enable {
    virtualisation.libvirtd.enable = true;

    networking.nat = {
      enable = true;
      extraCommands = ''
        iptables -F team-fw 2> /dev/null || true
        iptables -X team-fw 2> /dev/null || true
        iptables -N team-fw

        # Allow established.
        iptables -A team-fw -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

        # Allow DNS and DHCP.
        iptables -A team-fw -p udp -m udp --dport 53 -j ACCEPT
        iptables -A team-fw -p tcp -m tcp --dport 53 -j ACCEPT
        iptables -A team-fw -p udp -m udp --dport 67 -j ACCEPT
        iptables -A team-fw -p tcp -m tcp --dport 67 -j ACCEPT
        iptables -A team-fw -p icmp -m icmp --icmp-type 8 -j ACCEPT
        iptables -A team-fw -j DROP

        # Allow forwarding.
        iptables -t nat -A nixos-nat-pre -d ${ipAddress} -j DNAT --to ${cfg.guestAddress} # See internal-network.xml
        iptables -t nat -A nixos-nat-post -o teambr0 -j MASQUERADE
        iptables -t nat -A nixos-nat-post -o ${config.adLib.externalInterface} -j MASQUERADE
        iptables -t mangle -A POSTROUTING -o teambr0 -j TTL --ttl-set 64

        ${concatMapStringsSep "\n" (addr: ''
          iptables -A adlib-forward -i teambr0 -d ${addr.address}/${toString addr.prefixLength} -j ACCEPT
        '') cfg.allowedForwardAddresses}
        iptables -A adlib-forward -i teambr0 -d ${cfg.guestAddress} -j ACCEPT
        iptables -A adlib-forward -i teambr0 -d 192.168.0.0/16,172.16.0.0/12,10.0.0.0/8 -j DROP

        iptables -I INPUT 1 -i teambr0 -j team-fw
      '';
      extraStopCommands = ''
        iptables -t mangle -D POSTROUTING -o teambr0 -j TTL --ttl-set 64 2>/dev/null || true
        iptables -D INPUT -i teambr0 -j team-fw 2>/dev/null || true
      '';
    };

    environment.systemPackages = [ pkgs.libguestfs-with-appliance ];

    systemd.services.vulnbox = {
      description = "Team vulnbox VM.";
      after = [ "libvirtd.socket" "network.target" ];
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.libvirt pkgs.libguestfs-with-appliance pkgs.gzip ];
      restartIfChanged = false;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        StateDirectory = "vulnbox";
        StateDirectoryMode = "0700";
        PrivateTmp = true;
        ExecStop = stopVulnbox;
      };
      script =
        let
          networkConfig = pkgs.substituteAll {
            src = ./internal-network.xml;
            inherit (cfg) hostAddress netmask guestAddress;
          };
        in ''
          set -x
          ${stopVulnbox}
          virsh net-define ${networkConfig}
          virsh net-autostart --disable internal
          virsh net-start internal
          if [ ! -e /var/lib/libvirt/images/vulnbox.qcow2 ]; then
            mkdir -p /var/lib/libvirt/images
            zcat ${cfg.image} > /var/lib/libvirt/images/vulnbox.qcow2
          fi
          virsh define ${./vulnbox.xml}
          virsh autostart vulnbox --disable
          has_snapshot="$(virsh snapshot-info vulnbox --snapshotname oobe >/dev/null 2>&1 && echo "1" || true)"
          if [ ! -e /var/lib/vulnbox/password ] || [ -z "$has_snapshot" ]; then
            cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 16 > /tmp/password
            if [ -n "$has_snapshot" ]; then
              virsh snapshot-revert vulnbox --snapshotname oobe --paused
              virsh snapshot-delete vulnbox --snapshotname oobe
              virsh destroy vulnbox
            fi
            has_snapshot=""
            virt-customize -d vulnbox --password user:file:/tmp/password
            mv /tmp/password /var/lib/vulnbox/password
          fi
          if [ -z "$has_snapshot" ]; then
            virsh snapshot-create-as vulnbox --name oobe
          fi
          virsh start vulnbox
        '';
    };
  };
}
