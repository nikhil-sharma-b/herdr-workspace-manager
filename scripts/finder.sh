#!/usr/bin/env bash
# The finder, running inside the popup pane.
#
# It takes one session snapshot per refresh, builds rows from that single
# document, runs fzf, writes the chosen target to the per-invocation choice
# file and exits. Exiting closes the popup; the action process outside then
# performs the focus. Nothing in here ever changes session focus, so herdr is
# never asked to move focus underneath a modal popup.

set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$script_dir/lib/common.sh"

# fzf runs preview and execute commands through $SHELL. Inside the popup that
# is the user's login shell, so every preview would pay its startup cost.
export SHELL=/bin/sh

choice_file=${HWM_CHOICE:-}
correlation_id=${HWM_CORRELATION_ID:-$$}

run_dir="$(hwm_state_dir)/run-$correlation_id"
mkdir -p "$run_dir"

export HWM_RUN_DIR=$run_dir
export HWM_LOG_FILE="$run_dir/log"

# Recorded so that anything supervising this invocation — the test suite, or a
# future cleanup path — can address the finder directly rather than by pattern.
printf '%s' "$$" >"$run_dir/finder.pid"

finish() {
  local status=$1
  if [[ -n $choice_file ]]; then
    printf '%s' "${status}" >"$choice_file.tmp" 2>/dev/null || true
    mv -f "$choice_file.tmp" "$choice_file" 2>/dev/null || true
    : >"$choice_file.done" 2>/dev/null || true
  fi
  rm -rf "$run_dir"
}

# A killed popup must resolve the handoff too, or the action process outside
# waits out its whole timeout for a finder that is already gone. fzf therefore
# runs in the background and is waited on: a trap cannot run while a foreground
# child holds the shell.
fzf_pid=""
trap 'kill "$fzf_pid" 2>/dev/null; finish ""; exit 130' INT TERM HUP

fail() {
  printf '\n  %s\n\n' "$1" >&2
  hwm_log "$1"
  hwm_notify "workspace-manager" "$1"
  finish ""
  sleep 3
  exit 1
}

missing=$(hwm_missing_tools)
[[ -z $missing ]] || fail "workspace-manager needs: $missing"

hwm_load_config
hwm_load_preview_state

width=$(tput cols 2>/dev/null || printf '')
[[ $width =~ ^[0-9]+$ ]] || width=200
export HWM_WIDTH=$width

printf 'collapsed' >"$run_dir/mode"

if ! "$script_dir/refresh.sh" >"$run_dir/rows" 2>>"$HWM_LOG_FILE"; then
  fail "could not read the herdr session"
fi

preview_window="right,${HWM_PREVIEW_SIZE}%,border-left"
((HWM_PREVIEW_ENABLED)) || preview_window="$preview_window,hidden"

hwm_record_preview_state

set +e
"$(command -v fzf)" \
  --ansi \
  --delimiter=$'\t' \
  --with-nth=3 \
  --accept-nth=1 \
  --ellipsis='' \
  --no-multi \
  --height=100% \
  --layout=reverse \
  --border=none \
  --no-scrollbar \
  --info=hidden \
  --separator=' ' \
  --pointer='▌' \
  --marker=' ' \
  --tiebreak=begin,index \
  --color='fg:-1,bg:-1,hl:4,fg+:-1:regular,bg+:-1,hl+:12,info:8,prompt:8,pointer:4,marker:4,spinner:8,header:8,border:8,gutter:-1' \
  --padding='1,2' \
  --prompt="$("$script_dir/prompt.sh")" \
  --header='↵ jump · ^a view · ^n new · ^x close · ^r refresh · ^p preview · esc' \
  --header-first \
  --preview="$script_dir/preview.sh {1}" \
  --preview-window="$preview_window" \
  --bind="ctrl-p:toggle-preview+execute-silent($script_dir/toggle-preview.sh)" \
  --bind="ctrl-r:reload($script_dir/refresh.sh)" \
  --bind="ctrl-a:transform($script_dir/cycle-mode.sh {1})" \
  --bind="ctrl-n:execute($script_dir/create.sh {2})+transform($script_dir/after-create.sh)" \
  --bind="ctrl-x:execute($script_dir/close.sh {1})+reload($script_dir/refresh.sh)" \
  <"$run_dir/rows" >"$run_dir/selection" &
fzf_pid=$!
wait "$fzf_pid"
set -e

target=""
[[ -s $run_dir/selection ]] && target=$(head -n 1 "$run_dir/selection")
# Creating a workspace leaves the finder through `abort`, so its target is
# picked up here rather than from fzf's own output.
[[ -z $target && -s $run_dir/pending_target ]] && target=$(<"$run_dir/pending_target")

finish "$target"
