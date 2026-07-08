#!/usr/bin/env sh
set -eu

OVA_PATH="${1:-}"
if [ -z "$OVA_PATH" ]; then
  echo "Usage: $0 /path/to/PA-VM-ESX.ova" >&2
  exit 1
fi

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

tar -xf "$OVA_PATH" -C "$TMPDIR"
OVF="$(find "$TMPDIR" -maxdepth 1 -name '*.ovf' | head -n 1)"

if [ -z "$OVF" ]; then
  echo "No .ovf file found in OVA" >&2
  exit 1
fi

awk '
  /Network ovf:name=/ {
    line=$0
    sub(/^.*Network ovf:name="/, "", line)
    sub(/".*$/, "", line)
    print line
  }
' "$OVF"
