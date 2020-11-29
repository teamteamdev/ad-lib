#!/usr/bin/env bash

set -e

mydir="$(dirname "${BASH_SOURCE[0]}")"

usage() {
  echo "Usage: $0 <deployment> <jury-host>" >&2
  exit 1
}

deployment="$1"
shift || usage
juryHost="$1"
shift || usage

echo "Resetting $juryHost"
nixops ssh -d "$deployment" "$juryHost" "systemctl stop checksystem-frontend checksystem-manager checksystem-watcher checksystem-worker checksystem-checker-worker checksystem-init postgresql traffic-dump"
nixops ssh -d "$deployment" "$juryHost" "rm -rf /var/lib/traffic-dump /var/lib/checksystem /var/lib/postgresql"
echo "Finished resetting $juryHost"
