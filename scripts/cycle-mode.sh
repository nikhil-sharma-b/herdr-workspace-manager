#!/usr/bin/env bash
# Cycle collapsed → expanded → agents → collapsed.
#
# Run from fzf's `transform` binding: whatever this prints is executed as fzf
# actions. It re-renders the stored snapshot (never re-queries), moves the
# prompt to the new mode, and puts the cursor back on the same location when
# that location is still visible in the new view.

set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

run_dir=${HWM_RUN_DIR:?HWM_RUN_DIR is required}
current_target=${1:-}

mode=collapsed
[[ -f $run_dir/mode ]] && mode=$(<"$run_dir/mode")

case $mode in
  collapsed) next=expanded ;;
  expanded)  next=agents ;;
  *)         next=collapsed ;;
esac
printf '%s' "$next" >"$run_dir/mode"

prompt=$(HWM_MODE=$next "$script_dir/prompt.sh")

# Find where the previously selected location ended up. A pane row survives a
# mode change as itself; a collapsed workspace row survives as any row of that
# workspace.
position=0
if [[ -n $current_target ]]; then
  IFS='|' read -r _kind target_ws _target_tab target_pane <<<"$current_target"
  position=$("$script_dir/render.sh" | awk -F '\t' -v pane="$target_pane" -v ws="$target_ws" '
    {
      split($1, t, "|")
      if (t[4] != "" && t[4] == pane) { matched = 1; print NR - 1; exit }
      if (fallback == "" && t[2] == ws) { fallback = NR - 1 }
    }
    END { if (!matched) print (fallback == "" ? 0 : fallback) }
  ')
  [[ $position =~ ^[0-9]+$ ]] || position=0
fi

printf 'reload-sync(%s/render.sh)+change-prompt(%s)+pos(%s)' "$script_dir" "$prompt" "$((position + 1))"
