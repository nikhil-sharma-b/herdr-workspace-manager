#!/usr/bin/env bash
# One session snapshot, enriched with what each pane is actually running.
#
# The snapshot alone cannot say what a pane is doing: `terminal_title` is
# whatever the shell decided to set, which for fish is the working directory —
# useless for telling `lazygit` from `nvim`. `pane.process_info` knows, but only
# one pane at a time, so this is where the finder's per-refresh cost lives.
#
# It stays out of the row builder deliberately: rows remain a pure function of a
# document, and fixtures can describe a pane running anything.
#
# Prints the snapshot document with `process` added to every pane record.

set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$script_dir/lib/common.sh"

snapshot=$(herdr api snapshot 2>/dev/null) || {
  hwm_log "session snapshot failed"
  exit 1
}

jq -e 'has("result")' >/dev/null 2>&1 <<<"$snapshot" || {
  hwm_log "session snapshot returned an unexpected document"
  exit 1
}

processes=$(
  jq -r '.result.snapshot.panes[]?.pane_id' <<<"$snapshot" |
    while IFS= read -r pane_id; do
      [[ -n $pane_id ]] || continue
      herdr pane process-info --pane "$pane_id" 2>/dev/null || true
    done |
    jq -s 'map(.result.process_info? | select(. != null)) | INDEX(.pane_id)'
)
[[ -n $processes ]] || processes='{}'

jq --argjson processes "$processes" \
  '.result.snapshot.panes |= map(. + {process: ($processes[.pane_id] // null)})' \
  <<<"$snapshot"
