#!/usr/bin/env bash
# Close the thing the highlighted row represents.
#
# A pane row closes that pane; a collapsed workspace row closes that workspace.
# This is the only part of the finder that can destroy running work, so every
# close is confirmed, emptying the session is refused outright, and a close
# that would tear down a whole worktree group is confirmed a second time with
# the group spelled out.
#
# Usage: close.sh <target>

set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$script_dir/lib/common.sh"

target=${1:-}
[[ -n $target ]] || exit 0

IFS='|' read -r kind workspace_id _tab_id pane_id <<<"$target"

dim=$'\033[2m'
red=$'\033[31m'
bold=$'\033[1m'
reset=$'\033[0m'

refuse() {
  printf '\n%s%s%s\n' "$red" "$1" "$reset"
  hwm_log "close refused: $1"
  sleep 1.5
  exit 0
}

confirm() {
  local question=$1 answer
  printf '\n%s [y/N] ' "$question"
  IFS= read -r answer || answer=""
  case $answer in
    y | Y | yes | YES) return 0 ;;
    *) return 1 ;;
  esac
}

# Decisions are made against a fresh snapshot, never the finder's stored one:
# refusing to empty the session must not depend on how stale the list is.
snapshot=$(herdr api snapshot 2>/dev/null || true)
snapshot=$(jq -c 'if has("result") then .result.snapshot else . end' <<<"$snapshot" 2>/dev/null || true)
[[ -n $snapshot ]] || refuse "cannot reach herdr to check the session"

workspace_count=$(jq -r '(.workspaces // []) | length' <<<"$snapshot")
label=$(jq -r --arg w "$workspace_id" '(.workspaces // [])[] | select(.workspace_id == $w) | .label' <<<"$snapshot" | head -n 1)
panes_in_workspace=$(jq -r --arg w "$workspace_id" '[(.panes // [])[] | select(.workspace_id == $w)] | length' <<<"$snapshot")

if [[ $kind == c ]]; then
  ((workspace_count > 1)) || refuse "that is the last workspace — the session cannot be emptied"
  confirm "close workspace ${bold}${label:-$workspace_id}${reset} and everything in it?" || exit 0

  # herdr tears a worktree group down with its source workspace, and does so
  # without asking. Surface that as a second, explicit confirmation.
  group=$(jq -r --arg w "$workspace_id" '
      (.workspaces // []) as $all
      | ($all[] | select(.workspace_id == $w)) as $me
      | if ($me.worktree == null) or ($me.worktree.is_linked_worktree == true) then empty
        else
          $all[]
          | select(.workspace_id != $w)
          | select(.worktree != null and .worktree.is_linked_worktree == true)
          | select(.worktree.repo_key == $me.worktree.repo_key)
          | .label
        end' <<<"$snapshot" | paste -sd ', ' -)

  if [[ -n $group ]]; then
    printf '\n%sthis is the primary checkout of %s — closing it also closes its worktree group: %s%s\n' \
      "$red" "$(jq -r --arg w "$workspace_id" '(.workspaces // [])[] | select(.workspace_id == $w) | .worktree.repo_name' <<<"$snapshot")" "$group" "$reset"
    confirm "close the whole worktree group?" || {
      printf '%sleft alone%s\n' "$dim" "$reset"
      sleep 0.6
      exit 0
    }
  fi

  response=$(herdr workspace close "$workspace_id" 2>&1 || true)
  subject="workspace ${label:-$workspace_id}"
else
  [[ -n $pane_id ]] || exit 0
  if ((workspace_count <= 1 && panes_in_workspace <= 1)); then
    refuse "that is the last pane of the last workspace — the session cannot be emptied"
  fi
  confirm "close pane ${bold}${pane_id}${reset}?" || exit 0
  response=$(herdr pane close "$pane_id" 2>&1 || true)
  subject="pane $pane_id"
fi

error=$(hwm_api_error "$response")
code=$(hwm_api_error_code "$response")

if [[ $code == confirmation_required ]]; then
  # herdr asked for an explicit confirmation of its own. Its close methods take
  # no force flag, so the honest thing is to show the reason and stop.
  printf '\n%sherdr refused: %s%s\n' "$red" "$error" "$reset"
  printf '%sclose it from that workspace instead%s\n' "$dim" "$reset"
  hwm_log "close of $subject needs herdr-side confirmation: $error"
  sleep 2.5
  exit 0
fi

if [[ -n $error ]]; then
  printf '\n%scould not close %s: %s%s\n' "$red" "$subject" "$error" "$reset"
  hwm_log "close of $subject failed: $error"
  sleep 2
  exit 0
fi

hwm_log "closed $subject"
