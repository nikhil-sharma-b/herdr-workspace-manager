#!/usr/bin/env bash
# The `open` action — the thing a key binding invokes.
#
# It runs outside the popup as an ordinary spawned process, with stdout and
# stderr captured into herdr's plugin command log. That is deliberate: focus
# is moved from here, after the popup has closed, so herdr is never asked to
# move focus underneath a modal popup, and every failure stays visible in
# `herdr plugin log list`.

set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$script_dir/lib/common.sh"

readonly WAIT_TIMEOUT_SECONDS=${HWM_WAIT_TIMEOUT_SECONDS:-600}
readonly POLL_INTERVAL=0.05

state_dir=$(hwm_state_dir)
lock_file="$state_dir/finder.lock"

missing=$(hwm_missing_tools)
if [[ -n $missing ]]; then
  hwm_notify "workspace-manager" "install: $missing"
  exit 1
fi

# A second press while a finder is already open must not stack a second popup.
# The action process lives exactly as long as its popup, so its pid is the
# liveness test.
if [[ -f $lock_file ]]; then
  existing=$(<"$lock_file")
  if [[ $existing =~ ^[0-9]+$ ]] && kill -0 "$existing" 2>/dev/null; then
    hwm_log "finder already open (pid $existing); leaving it alone"
    exit 0
  fi
  hwm_log "clearing a stale lock from pid ${existing:-unknown}"
  rm -f "$lock_file"
fi

correlation_id="$(date +%s%N)-$$"
choice_file="$state_dir/choice-$correlation_id"

printf '%s' "$$" >"$lock_file"
: >"$choice_file"

cleanup() {
  # A finder that is still up when this process gives up would leave herdr with
  # a popup nobody is waiting on, and herdr allows only one popup at a time —
  # so the next press would be refused. The finder records its pid for exactly
  # this; it resolves its own handoff when signalled.
  local finder_pid_file="$state_dir/run-$correlation_id/finder.pid"
  if [[ -f $finder_pid_file ]]; then
    local finder_pid
    finder_pid=$(<"$finder_pid_file")
    if [[ $finder_pid =~ ^[0-9]+$ ]] && kill -0 "$finder_pid" 2>/dev/null; then
      hwm_log "closing a finder that outlived its invocation (pid $finder_pid)"
      kill "$finder_pid" 2>/dev/null || true
      # It writes the choice file as it goes down, so let it finish before the
      # files are removed — otherwise it recreates what this just deleted.
      local waited=0
      while kill -0 "$finder_pid" 2>/dev/null && ((waited < 30)); do
        sleep 0.1
        waited=$((waited + 1))
      done
    fi
  fi
  rm -f "$choice_file" "$choice_file.done" "$choice_file.tmp"
  rm -rf "$state_dir/run-$correlation_id"
  [[ -f $lock_file && $(<"$lock_file") == "$$" ]] && rm -f "$lock_file"
  return 0
}
# The signal traps must exit, not merely clean up: a trap that returns resumes
# the wait loop it interrupted.
trap cleanup EXIT
trap 'cleanup; exit 143' INT TERM HUP

response=$(herdr plugin pane open \
  --plugin "$(hwm_plugin_id)" \
  --entrypoint finder \
  --env "HWM_CHOICE=$choice_file" \
  --env "HWM_CORRELATION_ID=$correlation_id" \
  --focus 2>&1 || true)

error=$(hwm_api_error "$response")
if [[ -n $error ]]; then
  case $(hwm_api_error_code "$response") in
    ui_busy)
      hwm_notify "workspace-manager" "herdr will not open a popup right now — leave any overlay or picker first"
      ;;
    plugin_pane_open_failed)
      # herdr allows one popup at a time. Reaching this means a finder is
      # already up but its invocation is not one we know about, so say so
      # rather than reporting a generic API failure.
      if [[ $error == *"already open"* ]]; then
        hwm_notify "workspace-manager" "a popup is already open"
      else
        hwm_notify "workspace-manager" "could not open the finder: $error"
      fi
      ;;
    *)
      hwm_notify "workspace-manager" "could not open the finder: $error"
      ;;
  esac
  hwm_log "plugin.pane.open failed: $response"
  exit 1
fi

# Wait for the popup to resolve. The popup writes the choice file and then
# marks it done; the popup closes because its process exits.
deadline=$(( $(date +%s) + WAIT_TIMEOUT_SECONDS ))
while [[ ! -e "$choice_file.done" ]]; do
  if (( $(date +%s) >= deadline )); then
    hwm_log "finder did not resolve within ${WAIT_TIMEOUT_SECONDS}s; giving up and cleaning up"
    exit 0
  fi
  sleep "$POLL_INTERVAL"
done

target=$(head -n 1 "$choice_file" 2>/dev/null || printf '')

# Esc, or a finder that chose nothing: a normal abort, and never a notification.
if [[ -z $target ]]; then
  hwm_log "finder closed without a selection"
  exit 0
fi

status=0
"$script_dir/focus.sh" "$target" || status=$?

case $status in
  0) ;;
  3)
    hwm_notify "workspace-manager" "that location is gone — nothing was changed"
    exit 1
    ;;
  *)
    hwm_notify "workspace-manager" "could not focus the selected location"
    exit 1
    ;;
esac
