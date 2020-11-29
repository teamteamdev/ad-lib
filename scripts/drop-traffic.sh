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

echo "Stopping services for $teamHost"
nixops ssh -d "$deployment" "$teamHost" "systemctl stop packmate traffic-dump packmate-drop-older traffic-dump-drop-older"
nixops ssh -d "$deployment" "$teamHost" "rm -rf /var/lib/traffic-dump"
nixops ssh -d "$deployment" "$teamHost" "systemctl restart postgresql"
nixops ssh -d "$deployment" "$teamHost" "sudo -u postgres psql packmate -c 'drop table packet_matches; drop table found_pattern; drop table packet; drop table stream_found_patterns; drop table stream;'"
nixops ssh -d "$deployment" "$teamHost" "systemctl start packmate traffic-dump"
echo "Finished dropping traffic for $teamHost"
