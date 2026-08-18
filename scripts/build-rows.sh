#!/usr/bin/env bash
# Row builder seam: a session snapshot on stdin, finder rows on stdout.
#
# Deliberately pure — no server, no terminal, no state. Everything the finder
# renders is decided here, so it is testable from fixtures alone.
#
# Usage: build-rows.sh [--mode collapsed|expanded|agents] [--width N] [--home PATH]
#
# The snapshot may be given either bare (`{"workspaces":...}`) or still wrapped
# in its API response (`{"result":{"snapshot":...}}`).

set -euo pipefail

mode=collapsed
width=200
home=${HOME:-}

while (($#)); do
  case $1 in
    --mode) mode=${2:?}; shift 2 ;;
    --width) width=${2:?}; shift 2 ;;
    --home) home=${2-}; shift 2 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) printf 'build-rows.sh: unknown argument %s\n' "$1" >&2; exit 2 ;;
  esac
done

case $mode in
  collapsed|expanded|agents) ;;
  *) printf 'build-rows.sh: unknown mode %s\n' "$mode" >&2; exit 2 ;;
esac

[[ $width =~ ^[0-9]+$ ]] || width=200
((width >= 40)) || width=40

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

jq -c 'if has("result") then .result.snapshot elif has("snapshot") then .snapshot else . end' \
  | jq -r --arg mode "$mode" --arg home "$home" --argjson width "$width" -f "$script_dir/lib/rows.jq"
