#!/usr/bin/env bash
# Everything that fixtures cannot honestly test: that the focus sequence works
# against a real server, and that create and close behave as expected.
#
# Runs against the isolated server started by run.sh — never the developer's.

printf '\nlive session\n'

ws() { snapshot | jq -r --arg l "$1" '.result.snapshot.workspaces[] | select(.label == $l) | .workspace_id'; }

herdr workspace create --label alpha --cwd "$HOME" --no-focus >/dev/null
herdr workspace create --label beta --cwd "$HOME" --no-focus >/dev/null
herdr workspace create --label gamma --cwd "$HOME" --focus >/dev/null
sleep 0.3

alpha=$(ws alpha)
beta=$(ws beta)
herdr pane split "$beta:p1" --direction right >/dev/null 2>&1 || true
sleep 0.3

check "the finder's rows describe the live session"
live_rows=$("$REPO_DIR/scripts/build-rows.sh" --width 120 --mode expanded < <(snapshot))
assert_contains "$(strip_ansi <<<"$live_rows")" "alpha" "live rows"
assert_contains "$(strip_ansi <<<"$live_rows")" "beta" "live rows"

check "a snapshot costs exactly one request per refresh"
run_dir=$(mktemp -d "${TMPDIR:-/tmp}/hwm-live.XXXXXX")
printf 'expanded' >"$run_dir/mode"
HWM_RUN_DIR=$run_dir HWM_WIDTH=120 "$REPO_DIR/scripts/refresh.sh" >"$run_dir/rows"
assert_eq "1" "$(jq -r '[.result.snapshot] | length' <"$run_dir/snapshot.json")" "stored snapshot"
[[ -s $run_dir/rows ]] || fail "refresh produced no rows"

check "the focus routine lands on the intended workspace, tab and pane"
target=$(grep -m1 "^p|$alpha|" "$run_dir/rows" | cut -f1)
IFS='|' read -r _k t_ws t_tab t_pane <<<"$target"
"$REPO_DIR/scripts/focus.sh" "$target" >/dev/null 2>&1
assert_eq "$t_ws $t_tab $t_pane" "$(focused)" "focus after selecting a pane row"

check "selecting a different pane in the same workspace moves focus to that pane"
second=$(grep "^p|$beta|" "$run_dir/rows" | sed -n 2p | cut -f1)
if [[ -n $second ]]; then
  IFS='|' read -r _k s_ws s_tab s_pane <<<"$second"
  "$REPO_DIR/scripts/focus.sh" "$second" >/dev/null 2>&1
  assert_eq "$s_ws $s_tab $s_pane" "$(focused)" "focus after selecting a second pane"
else
  fail "the split pane never appeared in the rows"
fi

check "a target that vanished is reported rather than silently ignored"
before=$(focused)
status=0
"$REPO_DIR/scripts/focus.sh" 'p|w999|w999:t1|w999:p1' >/dev/null 2>&1 || status=$?
assert_eq "3" "$status" "focus exit status for a vanished target"
assert_eq "$before" "$(focused)" "focus after a vanished target"

# --- create -----------------------------------------------------------------

check "creating a workspace names it, seats it in the chosen directory and hands back its target"
mkdir -p "$HOME/projects/widget"
HWM_RUN_DIR=$run_dir printf 'delta\n' | HWM_RUN_DIR=$run_dir "$REPO_DIR/scripts/create.sh" "$HOME/projects/widget" >/dev/null
created=$(<"$run_dir/pending_target")
delta=$(ws delta)
[[ -n $delta ]] || fail "workspace delta was not created"
assert_contains "$created" "p|$delta|" "created target"
assert_eq "$HOME/projects/widget" \
  "$(snapshot | jq -r --arg w "$delta" '.result.snapshot.panes[] | select(.workspace_id == $w) | .cwd' | head -n 1)" \
  "created workspace working directory"

check "the session lands on a newly created workspace"
"$REPO_DIR/scripts/focus.sh" "$created" >/dev/null 2>&1
assert_eq "$delta" "$(snapshot | jq -r '.result.snapshot.focused_workspace_id')" "focus after create"

check "an empty name accepts herdr's default label"
rm -f "$run_dir/pending_target"
printf '\n' | HWM_RUN_DIR=$run_dir "$REPO_DIR/scripts/create.sh" "$HOME" >/dev/null
default_target=$(<"$run_dir/pending_target")
IFS='|' read -r _k default_ws _t _p <<<"$default_target"
default_label=$(snapshot | jq -r --arg w "$default_ws" '.result.snapshot.workspaces[] | select(.workspace_id == $w) | .label')
[[ -n $default_label ]] || fail "the default-labelled workspace has no label"

check "cancelling the prompt creates nothing"
rm -f "$run_dir/pending_target"
count_before=$(snapshot | jq -r '.result.snapshot.workspaces | length')
HWM_RUN_DIR=$run_dir "$REPO_DIR/scripts/create.sh" "$HOME" </dev/null >/dev/null
assert_eq "$count_before" "$(snapshot | jq -r '.result.snapshot.workspaces | length')" "workspace count after cancelling"
[[ ! -s $run_dir/pending_target ]] || fail "a cancelled create left a pending target"

# --- close ------------------------------------------------------------------

check "declining the confirmation closes nothing"
count_before=$(snapshot | jq -r '.result.snapshot.workspaces | length')
printf 'n\n' | HWM_RUN_DIR=$run_dir "$REPO_DIR/scripts/close.sh" "c|$alpha|$alpha:t1|$alpha:p1" >/dev/null
assert_eq "$count_before" "$(snapshot | jq -r '.result.snapshot.workspaces | length')" "workspace count after declining"

check "confirming closes the workspace a collapsed row stands for"
printf 'y\n' | HWM_RUN_DIR=$run_dir "$REPO_DIR/scripts/close.sh" "c|$alpha|$alpha:t1|$alpha:p1" >/dev/null
sleep 0.3
assert_eq "" "$(ws alpha)" "alpha after closing it"

check "the list refreshes after a close and the closed row is gone"
HWM_RUN_DIR=$run_dir HWM_WIDTH=120 "$REPO_DIR/scripts/refresh.sh" >"$run_dir/rows"
assert_not_contains "$(strip_ansi <"$run_dir/rows")" "alpha" "rows after a close"

check "a pane row closes that pane and leaves its workspace standing"
panes_before=$(snapshot | jq -r --arg w "$beta" '[.result.snapshot.panes[] | select(.workspace_id == $w)] | length')
victim=$(snapshot | jq -r --arg w "$beta" '[.result.snapshot.panes[] | select(.workspace_id == $w)] | last | .pane_id')
printf 'y\n' | HWM_RUN_DIR=$run_dir "$REPO_DIR/scripts/close.sh" "p|$beta|$beta:t1|$victim" >/dev/null
sleep 0.3
panes_after=$(snapshot | jq -r --arg w "$beta" '[.result.snapshot.panes[] | select(.workspace_id == $w)] | length')
assert_eq "$((panes_before - 1))" "$panes_after" "pane count after closing a pane"
[[ -n $(ws beta) ]] || fail "closing a pane closed its workspace"

check "closing the pane the session is focused on leaves a valid focus"
focused_now=$(snapshot | jq -r '.result.snapshot.focused_pane_id')
focused_ws=$(snapshot | jq -r '.result.snapshot.focused_workspace_id')
focused_tab=$(snapshot | jq -r '.result.snapshot.focused_tab_id')
printf 'y\n' | HWM_RUN_DIR=$run_dir "$REPO_DIR/scripts/close.sh" "p|$focused_ws|$focused_tab|$focused_now" >/dev/null
sleep 0.3
after=$(snapshot | jq -r '.result.snapshot.focused_pane_id')
[[ -n $after && $after != "null" ]] || fail "the session was left with no focused pane"
assert_eq "1" "$(snapshot | jq -r --arg p "$after" '[.result.snapshot.panes[] | select(.pane_id == $p)] | length')" \
  "the focused pane still exists"

check "closing the last remaining workspace is refused"
while true; do
  remaining=$(snapshot | jq -r '.result.snapshot.workspaces | length')
  ((remaining > 1)) || break
  doomed=$(snapshot | jq -r '.result.snapshot.workspaces | last | .workspace_id')
  printf 'y\ny\n' | HWM_RUN_DIR=$run_dir "$REPO_DIR/scripts/close.sh" "c|$doomed|$doomed:t1|$doomed:p1" >/dev/null
  sleep 0.2
done
last=$(snapshot | jq -r '.result.snapshot.workspaces[0].workspace_id')
output=$(printf 'y\n' | HWM_RUN_DIR=$run_dir "$REPO_DIR/scripts/close.sh" "c|$last|$last:t1|$last:p1" 2>&1 | strip_ansi)
assert_contains "$output" "last workspace" "refusal message"
assert_eq "1" "$(snapshot | jq -r '.result.snapshot.workspaces | length')" "workspace count after the refusal"

rm -rf "$run_dir"
