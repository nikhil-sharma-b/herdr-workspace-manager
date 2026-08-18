#!/usr/bin/env bash
# Failure UX and concurrency: nothing fails silently, and impatience is cheap.
#
# Runs against the isolated server started by run.sh.

printf '\nfailure paths\n'

state_dir="$HOME/.local/state/herdr/plugins/workspace-manager"

# The finder records its pid in its run directory, so these cases address it
# directly rather than by process-name pattern.
finder_pid() {
  local file
  file=$(find "$state_dir" -maxdepth 2 -name finder.pid 2>/dev/null | head -n 1)
  [[ -n $file ]] && cat "$file"
  return 0
}

await_gone() {
  local pid=$1 tries=${2:-60}
  while ((tries-- > 0)); do
    kill -0 "$pid" 2>/dev/null || return 0
    sleep 0.1
  done
  return 1
}

# Close whatever invocation is live and clear its state, so the next case starts
# from a session with no popup open — herdr refuses to open one on top of another.
clear_invocations() {
  local pid tries=40
  while ((tries-- > 0)); do
    pid=$(finder_pid)
    [[ -n $pid ]] || break
    kill "$pid" 2>/dev/null || true
    sleep 0.2
  done
  sleep 0.5
  rm -f "$state_dir"/choice-* "$state_dir/finder.lock" 2>/dev/null || true
  rm -rf "$state_dir"/run-* 2>/dev/null || true
  return 0
}


check "the plugin links from a local checkout and registers its action and pane"
linked=$(herdr plugin link "$REPO_DIR" 2>&1)
assert_contains "$linked" '"plugin_linked"' "link response"
listing=$(herdr plugin list --json 2>&1)
assert_contains "$listing" '"workspace-manager"' "plugin listing"
assert_contains "$listing" '"open"' "action listing"
assert_contains "$listing" '"finder"' "pane entrypoint listing"
assert_contains "$listing" '"popup"' "popup placement"

check "a missing dependency is named, notified and logged"
# A PATH with everything the action needs except the tools it must complain
# about, so the complaint is the only thing that can happen.
bare=$(mktemp -d "${TMPDIR:-/tmp}/hwm-bare.XXXXXX")
while IFS= read -r tool; do
  case ${tool##*/} in
    fzf | socat | python3 | python) continue ;;
  esac
  ln -sf "$tool" "$bare/${tool##*/}" 2>/dev/null || true
done < <(find /usr/bin /bin -maxdepth 1 -type f -o -maxdepth 1 -type l 2>/dev/null)
ln -sf "$HERDR_BIN" "$bare/herdr" 2>/dev/null || true
missing_output=$(PATH="$bare" "$REPO_DIR/scripts/open.sh" 2>&1 || true)
assert_contains "$missing_output" "fzf" "missing-dependency message"
assert_contains "$missing_output" "notify:" "missing-dependency log line"
rm -rf "$bare"

check "a vanished focus target is reported and changes nothing"
before=$(focused)
status=0
out=$("$REPO_DIR/scripts/focus.sh" 'p|w999|w999:t1|w999:p1' 2>&1) || status=$?
assert_eq "3" "$status" "focus exit status"
assert_contains "$out" "vanished" "diagnostic line"
assert_eq "$before" "$(focused)" "focus state"

check "an unresolved finder times out, cleans up its choice file and touches nothing"
rm -f "$state_dir"/choice-* "$state_dir/finder.lock" 2>/dev/null || true
before=$(focused)
HWM_WAIT_TIMEOUT_SECONDS=2 "$REPO_DIR/scripts/open.sh" >/dev/null 2>&1
assert_eq "$before" "$(focused)" "focus after a timed-out invocation"
leftovers=$(find "$state_dir" -maxdepth 1 -name 'choice-*' 2>/dev/null | wc -l | tr -d ' ')
assert_eq "0" "$leftovers" "leftover choice files"
[[ ! -f $state_dir/finder.lock ]] || fail "a timed-out invocation left its lock behind"

check "a second press focuses the finder that is open instead of stacking another"
rm -f "$state_dir"/choice-* "$state_dir/finder.lock" 2>/dev/null || true
mkdir -p "$state_dir"
sleep 60 &
holder=$!
printf '%s' "$holder" >"$state_dir/finder.lock"
panes_before=$(snapshot | jq -r '.result.snapshot.panes | length')
second=$("$REPO_DIR/scripts/open.sh" 2>&1 || true)
assert_contains "$second" "already open" "double-invocation diagnostic"
assert_eq "0" "$(find "$state_dir" -maxdepth 1 -name 'choice-*' | wc -l | tr -d ' ')" \
  "a second press must not mint a second invocation"
assert_eq "$panes_before" "$(snapshot | jq -r '.result.snapshot.panes | length')" \
  "pane count after a second press"
kill "$holder" 2>/dev/null || true
wait "$holder" 2>/dev/null || true
rm -f "$state_dir/finder.lock"

check "the action records its diagnostics in herdr's plugin command log"
herdr plugin action invoke open >/dev/null 2>&1 || true
sleep 1
logs=$(herdr plugin log list 2>&1)
assert_contains "$logs" "workspace-manager" "plugin command log"
assert_contains "$logs" '"open"' "logged action id"
clear_invocations

check "a stale lock from a dead process does not wedge the finder shut"
mkdir -p "$state_dir"
printf '999999' >"$state_dir/finder.lock"
out=$(HWM_WAIT_TIMEOUT_SECONDS=2 "$REPO_DIR/scripts/open.sh" 2>&1 || true)
assert_contains "$out" "stale lock" "stale-lock diagnostic"
rm -f "$state_dir"/choice-* "$state_dir/finder.lock" 2>/dev/null || true

check "a killed finder resolves its handoff instead of stranding the action"
clear_invocations
action_log=$(mktemp "${TMPDIR:-/tmp}/hwm-action.XXXXXX")
HWM_WAIT_TIMEOUT_SECONDS=60 "$REPO_DIR/scripts/open.sh" >"$action_log" 2>&1 &
action=$!
finder=""
tries=0
while ((tries < 80)); do
  tries=$((tries + 1))
  finder=$(finder_pid)
  [[ -n $finder ]] && break
  sleep 0.1
done
if [[ -n $finder ]]; then
  kill "$finder" 2>/dev/null || true
  await_gone "$action" || fail "the action outlived a killed finder by more than 6s"
else
  fail "the finder never started; the action said: $(tr '\n' ' ' <"$action_log")"
fi
rm -f "$action_log"
wait "$action" 2>/dev/null || true
assert_eq "0" "$(find "$state_dir" -maxdepth 1 -name 'choice-*' | wc -l | tr -d ' ')" \
  "choice files after a killed finder"
[[ ! -f $state_dir/finder.lock ]] || fail "a killed finder left the lock behind"

check "a terminated action exits instead of resuming its wait"
clear_invocations
HWM_WAIT_TIMEOUT_SECONDS=60 "$REPO_DIR/scripts/open.sh" >/dev/null 2>&1 &
action=$!
sleep 1
kill "$action" 2>/dev/null || true
await_gone "$action" || fail "the action ignored SIGTERM and kept waiting"
wait "$action" 2>/dev/null || true
clear_invocations

check "an aborted finder produces no notification"
run_dir=$(mktemp -d "${TMPDIR:-/tmp}/hwm-abort.XXXXXX")
choice="$run_dir/choice"
: >"$choice"
: >"$choice.done"
out=$(HWM_WAIT_TIMEOUT_SECONDS=2 bash -c '
  source "'"$REPO_DIR"'/scripts/lib/common.sh"
  target=$(head -n 1 "'"$choice"'")
  [[ -z $target ]] && hwm_log "finder closed without a selection"' 2>&1)
assert_contains "$out" "without a selection" "abort diagnostic"
assert_not_contains "$out" "notify" "abort notification"
rm -rf "$run_dir"

herdr plugin unlink workspace-manager >/dev/null 2>&1 || true
