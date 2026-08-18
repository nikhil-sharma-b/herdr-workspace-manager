#!/usr/bin/env bash
# The finder prompt, which names the active view mode. Reads HWM_MODE, or the
# stored mode when that is not set.

set -euo pipefail

mode=${HWM_MODE:-}
if [[ -z $mode && -n ${HWM_RUN_DIR:-} && -f ${HWM_RUN_DIR}/mode ]]; then
  mode=$(<"${HWM_RUN_DIR}/mode")
fi

case $mode in
  expanded) printf 'panes ▸ ' ;;
  agents)   printf 'agents ▸ ' ;;
  *)        printf 'workspaces ▸ ' ;;
esac
