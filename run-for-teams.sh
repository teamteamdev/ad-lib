#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash jq parallel

set -e

mapAllHosts() {
  local deployment="$1"

  local type
  local host

  teamHosts=()
  juryHost=""

  while read line; do
    args=($line)
    type="${args[0]}"
    host="${args[1]}"

    case "$type" in
      team)
        teamHosts+=("$host")
        ;;
      jury)
        juryHost="$host"
        ;;
    esac
  done < <(nixops export -d "$deployment" | jq -r '.[keys | first].resources | keys | .[]' | parallel determineHost "$deployment")
}

usage() {
  echo "Usage: $0 <deployment> <script> args..." >&2
  exit 1
}

deployment="$1"
shift || usage
script="$1"
shift || usage

determineHost() {
  local deployment="$1"
  local host="$2"

  if [ "$(nixops show-option -d "$deployment" "$host" adLib.teamHost.enable)" = "true" ]; then
    echo "team $host"
  elif [ "$(nixops show-option -d "$deployment" "$host" adLib.juryHost.enable)" = "true" ]; then
    echo "jury $host"
  fi
}

export -f determineHost

teamHosts=()
juryHost=""

while read line; do
  args=($line)
  type="${args[0]}"
  host="${args[1]}"

  case "$type" in
    team)
      teamHosts+=("$host")
      ;;
    jury)
      juryHost="$host"
      ;;
  esac
done < <(nixops export -d "$deployment" | jq -r '.[keys | first].resources | keys | .[]' | parallel determineHost "$deployment")

unset -f determineHost 

parallel -j4 "$script" "$deployment" "$juryHost" {} "$@" -s {.} -all -qcache ::: "${teamHosts[@]}"
