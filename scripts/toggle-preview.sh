#!/usr/bin/env bash
# Record that the user just toggled the preview, so the next finder opens the
# same way. Bound alongside fzf's own toggle-preview: both flip on every press,
# starting from the same value, so they stay in step.

set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$script_dir/lib/common.sh"

file=$(hwm_preview_state_file)

current=off
[[ -f $file ]] && current=$(<"$file")

if [[ $current == on ]]; then
  printf 'off' >"$file"
else
  printf 'on' >"$file"
fi
