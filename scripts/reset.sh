#!/usr/bin/env bash

set -e

mydir="$(dirname "${BASH_SOURCE[0]}")"

usage() {
  echo "Usage: $0 <deployment> <jury-host> <host>" >&2
  exit 1
}

deployment="$1"
shift || usage
juryHost="$1"
shift || usage
teamHost="$1"
shift || usage

echo "Resetting $teamHost"
nixops ssh -d "$deployment" "$teamHost" "systemctl stop vulnbox openvpn-team-network uwsgi destructive-farm-submit packmate traffic-dump packmate-drop-older traffic-dump-drop-older postgresql"
nixops ssh -d "$deployment" "$teamHost" "virsh snapshot-delete vulnbox --snapshotname oobe; virsh undefine vulnbox --remove-all-storage"
nixops ssh -d "$deployment" "$teamHost" "rm -rf /var/lib/traffic-dump /var/lib/vulnbox /var/lib/libvirt/images/vulnbox.qcow2 /var/lib/postgresql /var/lib/destructive-farm"
echo "Finished resetting $teamHost"
