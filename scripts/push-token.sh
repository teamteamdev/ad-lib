#!/usr/bin/env bash

set -e

usage() {
  echo "Usage: $0 <deployment> <jury-host> <team-host?" >&2
  exit 1
}

deployment="$1"
shift || usage
juryHost="$1"
shift || usage
teamHost="$1"
shift || usage

internalIp="$(nixops show-option -d "$deployment" "$teamHost" adLib.p2pTunnels.ipAddress | jq -r)"
nixops ssh -d "$deployment" "$juryHost" -- cat "/var/lib/checksystem/teams/${internalIp}-token" | nixops ssh -d "$deployment" "$teamHost" -- "cat > /var/lib/destructive-farm/token"
