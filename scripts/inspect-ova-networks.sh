#!/usr/bin/env sh
set -eu

OVA_PATH="${1:-}"
if [ -z "$OVA_PATH" ]; then
  echo "Usage: $0 /path/to/PA-VM-ESX.ova" >&2
  exit 1
fi

OVF="$(tar -tf "$OVA_PATH" | awk '/\.ovf$/ { print; exit }')"

if [ -z "$OVF" ]; then
  echo "No .ovf file found in OVA" >&2
  exit 1
fi

tar -xOf "$OVA_PATH" "$OVF" |
awk '
  /Network ovf:name=/ {
    line=$0
    sub(/^.*Network ovf:name="/, "", line)
    sub(/".*$/, "", line)
    print line
  }
'
