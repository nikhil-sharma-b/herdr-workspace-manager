#!/usr/bin/env bash
# Land the session on a target chosen in the finder.
#
# Walked workspace → tab → pane rather than assuming a pane focus pulls its
# ancestors along: whether the implicit behaviour holds is unverified, and the
# explicit sequence is correct either way.
#
# Exits 0 on success, 3 when the target no longer exists, 1 on anything else.
#
# Usage: focus.sh <target>

set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$script_dir/lib/common.sh"

target=${1:-}
[[ -n $target ]] || exit 0

IFS='|' read -r _kind workspace_id tab_id pane_id <<<"$target"

gone() {
  hwm_log "focus target vanished: $target ($1)"
  exit 3
}

if [[ -n $workspace_id ]]; then
  out=$(herdr workspace focus "$workspace_id" 2>&1 || true)
  err=$(hwm_api_error "$out")
  [[ -z $err ]] || gone "workspace: $err"
fi

if [[ -n $tab_id ]]; then
  out=$(herdr tab focus "$tab_id" 2>&1 || true)
  err=$(hwm_api_error "$out")
  [[ -z $err ]] || gone "tab: $err"
fi

if [[ -n $pane_id ]]; then
  out=$(hwm_api pane.focus "$(jq -nc --arg id "$pane_id" '{pane_id: $id}')")
  err=$(hwm_api_error "$out")
  [[ -z $err ]] || gone "pane: $err"
fi

hwm_log "focused $target"
