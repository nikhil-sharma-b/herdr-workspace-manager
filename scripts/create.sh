#!/usr/bin/env bash
# Create a workspace from inside the finder.
#
# Runs under fzf's `execute`, so it owns the popup's terminal while it prompts.
# The working directory is inherited from the highlighted row, because the
# reason the finder was open is that the user was already thinking about that
# repository. An empty name accepts herdr's default label; Ctrl-D or Ctrl-C
# cancels and creates nothing.
#
# On success the new workspace's target is left in the run directory; the
# finder then aborts and the action process focuses it, so creating and
# switching are one action.
#
# Usage: create.sh <cwd>

set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$script_dir/lib/common.sh"

run_dir=${HWM_RUN_DIR:?HWM_RUN_DIR is required}
cwd=${1:-}

dim=$'\033[2m'
red=$'\033[31m'
reset=$'\033[0m'

printf '\n'
if [[ -n $cwd ]]; then
  printf '%snew workspace in %s%s\n' "$dim" "$cwd" "$reset"
fi
printf 'name %s(empty for herdr default, ctrl-d to cancel)%s: ' "$dim" "$reset"

if ! IFS= read -r name; then
  printf '\n%scancelled%s\n' "$dim" "$reset"
  sleep 0.4
  exit 0
fi

args=(workspace create --no-focus)
[[ -n $name ]] && args+=(--label "$name")
[[ -n $cwd && -d $cwd ]] && args+=(--cwd "$cwd")

response=$(herdr "${args[@]}" 2>&1 || true)
error=$(hwm_api_error "$response")

if [[ -n $error ]]; then
  printf '%scould not create workspace: %s%s\n' "$red" "$error" "$reset"
  hwm_log "create failed: $error"
  sleep 2
  exit 0
fi

target=$(jq -r '
    .result as $r
    | if $r == null then "" else
        "p|" + ($r.workspace.workspace_id // "")
          + "|" + ($r.tab.tab_id // $r.workspace.active_tab_id // "")
          + "|" + ($r.root_pane.pane_id // "")
      end' <<<"$response" 2>/dev/null || true)

if [[ -z $target || $target == "p|||" ]]; then
  printf '%sworkspace created, but herdr did not report where%s\n' "$red" "$reset"
  hwm_log "create returned an unusable response: $response"
  sleep 2
  exit 0
fi

printf '%s' "$target" >"$run_dir/pending_target"
