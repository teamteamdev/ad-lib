#!/usr/bin/env bash

set -e

mydir="$(dirname "${BASH_SOURCE[0]}")"

usage() {
  echo "Usage: $0 <deployment> <jury-host> <host> <path>" >&2
  exit 1
}

deployment="$1"
shift || usage
juryHost="$1"
shift || usage
teamHost="$1"
shift || usage
basePath="$1"
shift || usage

path="$basePath/$teamHost"

mkdir -p "$path"

ip="$(nixops show-option -d "$deployment" "$teamHost" deployment.targetHost | jq -r)"
sed "s,@remote@,$ip,g" "$mydir/client.ovpn.template" > "$path/client.ovpn"
echo -en "\n<ca>\n" >> "$path/client.ovpn"
nixops ssh -d "$deployment" "$teamHost" cat /var/lib/team-network/pki/ca.crt >> "$path/client.ovpn"
echo -en "\n</ca>\n\n<cert>\n" >> "$path/client.ovpn"
nixops ssh -d "$deployment" "$teamHost" cat /var/lib/team-network/pki/issued/client.crt >> "$path/client.ovpn"
echo -en "\n</cert>\n\n<key>\n" >> "$path/client.ovpn"
nixops ssh -d "$deployment" "$teamHost" cat /var/lib/team-network/pki/private/client.key >> "$path/client.ovpn"
echo -en "\n</key>\n" >> "$path/client.ovpn"

password="$(nixops ssh -d "$deployment" "$teamHost" -- cat /var/lib/vulnbox/password)"
echo "user:$password" > "$path/creds"
nixops scp -d "$deployment" --from "$teamHost" /var/lib/destructive-farm/token "$path/token"
