#!/usr/bin/env bash
# Shared helpers for the workspace-manager plugin.
#
# Every script sources this. It provides the socket client, logging, herdr
# notifications, configuration loading and the per-invocation run directory.

hwm_plugin_id() { printf 'workspace-manager'; }

hwm_root() {
  if [[ -n ${HERDR_PLUGIN_ROOT:-} ]]; then
    printf '%s' "$HERDR_PLUGIN_ROOT"
  else
    (cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
  fi
}

hwm_state_dir() {
  local dir=${HERDR_PLUGIN_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/herdr/plugins/workspace-manager}
  mkdir -p "$dir"
  printf '%s' "$dir"
}

hwm_config_dir() {
  printf '%s' "${HERDR_PLUGIN_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/herdr/plugins/config/workspace-manager}"
}

# Diagnostics go to stderr, which herdr captures into the plugin command log
# for action processes. Popup entrypoints additionally tee into a log file,
# because a popup's stderr is its own terminal and disappears with it.
hwm_log() {
  printf '[workspace-manager] %s\n' "$*" >&2
  if [[ -n ${HWM_LOG_FILE:-} ]]; then
    printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >>"$HWM_LOG_FILE" 2>/dev/null || true
  fi
}

hwm_notify() {
  local title=$1 body=${2:-}
  hwm_log "notify: $title${body:+ — $body}"
  if [[ -n $body ]]; then
    herdr notification show "$title" --body "$body" >/dev/null 2>&1 || true
  else
    herdr notification show "$title" >/dev/null 2>&1 || true
  fi
}

# --- socket client ----------------------------------------------------------
#
# Most of what the plugin needs has a CLI verb. `pane.focus` does not: the CLI
# only focuses a *neighbouring* pane by direction, while the API focuses a pane
# by id. So a small raw client is required. socat is preferred; python3 is the
# fallback. Both are checked by hwm_require_tools.

hwm_socket_path() { printf '%s' "${HERDR_SOCKET_PATH:-}"; }

hwm_api() {
  local method=$1 params=${2:-'{}'} socket
  socket=$(hwm_socket_path)
  if [[ -z $socket ]]; then
    printf '{"error":{"code":"no_socket","message":"HERDR_SOCKET_PATH is not set"}}'
    return 0
  fi
  local request
  request=$(printf '{"id":"workspace-manager","method":"%s","params":%s}' "$method" "$params")

  if command -v socat >/dev/null 2>&1; then
    printf '%s\n' "$request" | socat -t5 - "UNIX-CONNECT:$socket" 2>/dev/null | head -n 1
  elif command -v python3 >/dev/null 2>&1; then
    HWM_REQUEST=$request HWM_SOCKET=$socket python3 - <<'PY' 2>/dev/null
import os, socket, sys
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.settimeout(5)
try:
    s.connect(os.environ["HWM_SOCKET"])
    s.sendall((os.environ["HWM_REQUEST"] + "\n").encode())
    buf = b""
    while b"\n" not in buf:
        chunk = s.recv(65536)
        if not chunk:
            break
        buf += chunk
    sys.stdout.write(buf.split(b"\n")[0].decode())
finally:
    s.close()
PY
  else
    printf '{"error":{"code":"no_client","message":"neither socat nor python3 is available"}}'
  fi
}

# Prints the error message of an API response, or nothing when it succeeded.
hwm_api_error() {
  jq -r 'if .error then (.error.message // .error.code // "unknown API error") else empty end' 2>/dev/null <<<"${1:-}"
}

hwm_api_error_code() {
  jq -r 'if .error then (.error.code // "unknown") else empty end' 2>/dev/null <<<"${1:-}"
}

# --- dependencies -----------------------------------------------------------

# Echoes a human-readable list of missing dependencies, empty when satisfied.
hwm_missing_tools() {
  local missing=()
  command -v fzf >/dev/null 2>&1 || missing+=(fzf)
  command -v jq >/dev/null 2>&1 || missing+=(jq)
  if ! command -v socat >/dev/null 2>&1 && ! command -v python3 >/dev/null 2>&1; then
    missing+=("socat (or python3)")
  fi
  ((${#missing[@]})) && printf '%s' "${missing[*]}"
  return 0
}

# --- configuration ----------------------------------------------------------
#
# Optional config.toml in the herdr-provided plugin config directory. Only a
# tiny, forgiving subset is read: `key = value` lines. Anything unparseable is
# ignored so a malformed file can never break the finder.

# The preview is off unless asked for: the list is what the finder is for, and a
# preview costs half the width. Ctrl-p turns it on, and that choice sticks (see
# hwm_load_preview_state).
HWM_PREVIEW_ENABLED=0
HWM_PREVIEW_SIZE=50

hwm_load_config() {
  local file="$(hwm_config_dir)/config.toml"
  [[ -f $file ]] || return 0
  local key value
  while IFS= read -r line; do
    line=${line%%#*}
    [[ $line == *=* ]] || continue
    key=${line%%=*}
    value=${line#*=}
    key=$(printf '%s' "$key" | tr -d '[:space:]')
    value=$(printf '%s' "$value" | tr -d '[:space:]"'"'")
    case $key in
      preview)
        case $value in
          true|on|yes|1) HWM_PREVIEW_ENABLED=1 ;;
          false|off|no|0) HWM_PREVIEW_ENABLED=0 ;;
        esac
        ;;
      preview_size)
        value=${value%\%}
        [[ $value =~ ^[0-9]+$ ]] && ((value >= 10 && value <= 90)) && HWM_PREVIEW_SIZE=$value
        ;;
    esac
  done <"$file"
  return 0
}

# Ctrl-p's choice outlives the popup. fzf's own toggle is runtime state inside
# one process, and every invocation is a new process, so the finder records the
# state itself and reads it back here. A recorded choice outranks the config
# file: it is the more recent thing the user said.
hwm_preview_state_file() { printf '%s/preview' "$(hwm_state_dir)"; }

hwm_load_preview_state() {
  local file
  file=$(hwm_preview_state_file)
  [[ -f $file ]] || return 0
  case $(<"$file") in
    on) HWM_PREVIEW_ENABLED=1 ;;
    off) HWM_PREVIEW_ENABLED=0 ;;
  esac
  return 0
}

# Record what a popup actually opened with, so the first Ctrl-p flips the stored
# value the right way even when the config file, not a previous toggle, chose
# the starting value.
hwm_record_preview_state() {
  if ((HWM_PREVIEW_ENABLED)); then
    printf 'on' >"$(hwm_preview_state_file)"
  else
    printf 'off' >"$(hwm_preview_state_file)"
  fi
  return 0
}
