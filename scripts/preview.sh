#!/usr/bin/env bash
# Preview for the highlighted row: the pane's recent output, escape sequences
# stripped and line count bounded.
#
# One path for every row type. A collapsed workspace row leads with a short
# inventory of the panes inside that workspace, so collapsing never costs
# information at the moment it is needed.
#
# Usage: preview.sh <target>   (target as emitted by build-rows.sh, field 1)

set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$script_dir/lib/common.sh"

target=${1:-}
[[ -n $target ]] || exit 0

IFS='|' read -r kind workspace_id _tab_id pane_id <<<"$target"

run_dir=${HWM_RUN_DIR:-}
lines=${HWM_PREVIEW_LINES:-200}

dim=$'\033[2m'
bold=$'\033[1m'
reset=$'\033[0m'

if [[ $kind == c && -n $run_dir && -f $run_dir/snapshot.json ]]; then
  printf '%s%s%s\n' "$bold" "panes in this workspace" "$reset"
  # Named the same way the rows are: an explicit rename, else what the pane is
  # running, else whatever the shell put in the title.
  jq -r --arg ws "$workspace_id" --arg home "${HOME:-}" '
      def running:
        (.process // null) as $info
        | if $info == null then ""
          else (($info.foreground_processes // []) | last) as $top
            | if $top == null or ($top.pid == $info.shell_pid) then ""
              else (($top.argv // [($top.name // "")]) | map(select(. != null and . != "")))
                   | if length == 0 then "" else (.[0] |= (split("/") | last)) | join(" ") end
              end
          end;
      (if has("result") then .result.snapshot else . end) as $s
      | ($s.panes // []) | map(select(.workspace_id == $ws))[]
      | ((.foreground_cwd // .cwd // "") | if ($home != "" and startswith($home)) then "~" + .[($home|length):] else . end) as $cwd
      | (if ((.label // "") != "") then .label
         elif (running != "") then running
         else (.terminal_title_stripped // .terminal_title // .pane_id) end) as $name
      | "  " + ($name | gsub("[\t\r\n]"; " "))
        + (if $cwd == "" then "" else "  ·  " + $cwd end)
    ' <"$run_dir/snapshot.json" 2>/dev/null || true
  printf '\n'
fi

if [[ -z $pane_id ]]; then
  printf '%sno pane to preview%s\n' "$dim" "$reset"
  exit 0
fi

# A slow or wedged pane read must never stall the list, so the read is bounded.
# herdr reports a missing pane on stderr with a non-zero status, which is the
# one case worth a message of its own.
status=0
output=$(timeout 2 herdr pane read "$pane_id" --source recent --lines "$lines" --format text 2>/dev/null) || status=$?
if ((status == 0)) && [[ -z ${output//[$'\n\r\t ']/} ]]; then
  output=$(timeout 2 herdr pane read "$pane_id" --source visible --format text 2>/dev/null) || status=$?
fi

if ((status != 0)) || [[ $output == '{"error"'* ]]; then
  printf '%sthis pane is gone — press ctrl-r to refresh the list%s\n' "$dim" "$reset"
  exit 0
fi

if [[ -z ${output//[$'\n\r\t ']/} ]]; then
  printf '%sno output yet%s\n' "$dim" "$reset"
  exit 0
fi

printf '%s\n' "$output" | tail -n "$lines"
