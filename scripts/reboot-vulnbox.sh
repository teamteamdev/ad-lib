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

echo "Rebooting vulnbox for $teamHost"
nixops ssh -d "$deployment" "$teamHost" systemctl restart vulnbox
echo "Finished rebooting vulnbox for $teamHost"
