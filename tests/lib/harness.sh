#!/usr/bin/env bash
# Test harness: assertions, and an isolated herdr server.
#
# Isolation is the point. A headless herdr server started without an explicit
# private socket restores the developer's real persisted session from their
# config directory — and can rewrite it. Every server this harness starts gets
# BOTH a private socket path and a private HOME/XDG tree, so the suite can
# neither read nor write live session state.
#
# Socket paths also have a sun_path length limit, so the socket lives at a
# short path under /tmp rather than beside the rest of the fixtures.
#
# This is a library: it deliberately sets no shell options. run.sh owns those,
# and must not run under `set -e` — a failed assertion has to be recorded and
# reported, not abort the suite silently.

REPO_DIR=${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}
HERDR_BIN=${HERDR_BIN:-$(command -v herdr || true)}

TESTS_RUN=0
TESTS_FAILED=0
CURRENT_TEST=""

fail() {
  printf '  \033[31m✘ %s\033[0m\n      %s\n' "$CURRENT_TEST" "$1" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
  return 0
}

check() {
  CURRENT_TEST=$1
  TESTS_RUN=$((TESTS_RUN + 1))
  printf '  \033[2m·\033[0m %s\n' "$1"
}

assert_eq() {
  local expected=$1 actual=$2 what=${3:-values}
  [[ $expected == "$actual" ]] || fail "$what: expected [$expected], got [$actual]"
}

assert_contains() {
  local haystack=$1 needle=$2 what=${3:-output}
  [[ $haystack == *"$needle"* ]] || fail "$what does not contain [$needle]"
}

assert_not_contains() {
  local haystack=$1 needle=$2 what=${3:-output}
  [[ $haystack != *"$needle"* ]] || fail "$what unexpectedly contains [$needle]"
}

strip_ansi() { sed 's/\x1b\[[0-9;]*m//g'; }

# --- row builder ------------------------------------------------------------

# rows <fixture> [args...] — rendered rows for a fixture snapshot.
rows() {
  local fixture=$1
  shift
  "$REPO_DIR/scripts/build-rows.sh" --home /home/dev --width 120 "$@" <"$REPO_DIR/tests/fixtures/$fixture"
}

# Fuzzy-filter rendered rows non-interactively, exactly as the finder matches:
# on the display field only, hidden tail included.
filter_rows() {
  local query=$1
  fzf --filter="$query" --delimiter=$'\t' --with-nth=3 --tiebreak=begin,index 2>/dev/null || true
}

targets() { cut -f1; }

# --- isolated server --------------------------------------------------------

HERDR_TEST_HOME=""
HERDR_TEST_SOCKET=""
HERDR_TEST_SERVER_PID=""

start_isolated_herdr() {
  HERDR_TEST_HOME=$(mktemp -d "${TMPDIR:-/tmp}/hwm-test-home.XXXXXX")
  HERDR_TEST_SOCKET="/tmp/hwm-test-$$.sock"

  mkdir -p "$HERDR_TEST_HOME/.config" "$HERDR_TEST_HOME/.local/share" "$HERDR_TEST_HOME/.local/state"

  export HOME="$HERDR_TEST_HOME"
  export XDG_CONFIG_HOME="$HERDR_TEST_HOME/.config"
  export XDG_DATA_HOME="$HERDR_TEST_HOME/.local/share"
  export XDG_STATE_HOME="$HERDR_TEST_HOME/.local/state"
  export HERDR_SOCKET_PATH="$HERDR_TEST_SOCKET"

  "$HERDR_BIN" server >"$HERDR_TEST_HOME/server.log" 2>&1 &
  HERDR_TEST_SERVER_PID=$!

  local waited=0
  while [[ ! -S $HERDR_TEST_SOCKET ]]; do
    sleep 0.1
    waited=$((waited + 1))
    if ((waited > 100)); then
      printf 'isolated herdr server did not start; log:\n' >&2
      cat "$HERDR_TEST_HOME/server.log" >&2
      exit 1
    fi
  done
}

stop_isolated_herdr() {
  [[ -n $HERDR_TEST_SOCKET ]] || return 0
  HERDR_SOCKET_PATH="$HERDR_TEST_SOCKET" "$HERDR_BIN" server stop >/dev/null 2>&1 || true
  if [[ -n $HERDR_TEST_SERVER_PID ]]; then
    kill "$HERDR_TEST_SERVER_PID" 2>/dev/null || true
    wait "$HERDR_TEST_SERVER_PID" 2>/dev/null || true
  fi
  rm -f "$HERDR_TEST_SOCKET"
  [[ -n $HERDR_TEST_HOME ]] && rm -rf "$HERDR_TEST_HOME"
  return 0
}

snapshot() { "$HERDR_BIN" api snapshot; }

focused() {
  snapshot | jq -r '.result.snapshot | [.focused_workspace_id, .focused_tab_id, .focused_pane_id] | join(" ")'
}
