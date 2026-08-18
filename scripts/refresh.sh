#!/usr/bin/env bash
# Take one session snapshot and render the current view from it.
#
# This is the only place the finder queries the session: on open, on Ctrl-r,
# and after a create or close. Typing, moving the selection and switching view
# mode all re-render the stored snapshot instead (see render.sh).

set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$script_dir/lib/common.sh"

run_dir=${HWM_RUN_DIR:?HWM_RUN_DIR is required}

if herdr api snapshot >"$run_dir/snapshot.next" 2>"$run_dir/snapshot.err"; then
  if jq -e 'has("result")' >/dev/null 2>&1 <"$run_dir/snapshot.next"; then
    mv "$run_dir/snapshot.next" "$run_dir/snapshot.json"
  else
    hwm_log "snapshot returned an unexpected document; keeping the previous one"
  fi
else
  hwm_log "snapshot failed: $(head -n 1 "$run_dir/snapshot.err" 2>/dev/null)"
fi

exec "$script_dir/render.sh"
