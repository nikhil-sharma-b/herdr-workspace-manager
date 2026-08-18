#!/usr/bin/env bash
# Collapsed, expanded and agents-only, over sessions of shells, agents and both.

printf '\nview modes\n'

check "a session of only shells collapses to one row per workspace"
assert_eq "c|w1|w1:t1|w1:p1 c|w2|w2:t1|w2:p1 c|w3|w3:t1|w3:p1" \
  "$(rows shells-only.json --mode collapsed | targets | paste -sd ' ' -)" \
  "collapsed rows"

check "the expanded view of the same session shows every pane"
assert_eq "5" "$(rows shells-only.json --mode expanded | wc -l | tr -d ' ')" "expanded rows"

check "the agents-only view of a session with no agents is empty"
assert_eq "0" "$(rows shells-only.json --mode agents | wc -l | tr -d ' ')" "agent rows"

check "the agents view shows every agent pane"
assert_eq "4" "$(rows mixed-agents.json --mode agents | wc -l | tr -d ' ')" "agent rows"

check "the workspaces view lists workspaces and nothing else"
collapsed=$(rows mixed-agents.json --mode collapsed | targets | paste -sd ' ' -)
assert_eq "c|w1|w1:t1|w1:p2 c|w2|w2:t1|w2:p1 c|w3|w3:t1|w3:p1" "$collapsed" "collapsed rows"

check "a workspace full of agents is still one row"
assert_eq "1" "$(rows mixed-agents.json --mode collapsed | grep -c '^c|w3')" "rows for a three-agent workspace"

check "a workspace with both an agent and a shell is one row"
assert_eq "1" "$(rows mixed-agents.json --mode collapsed | grep -c '^c|w1')" "rows for a mixed workspace"

check "a workspace row takes its status from the workspace, not from one pane"
row=$(rows mixed-agents.json --mode collapsed | grep '^c|w1' | cut -f3)
assert_contains "$row" $'\033[31m' "blocked workspace colour"

check "a workspace row names its agent, and counts them when there are several"
assert_contains "$(rows mixed-agents.json --mode collapsed | grep '^c|w1' | cut -f3 | strip_ansi)" \
  "claude" "single agent named on the workspace row"
assert_contains "$(rows mixed-agents.json --mode collapsed | grep '^c|w3' | cut -f3 | strip_ansi)" \
  "3 agents" "agent count on the workspace row"

check "a workspace row matches an agent name typed in the workspaces view"
assert_eq "c|w3|w3:t1|w3:p1" \
  "$(rows mixed-agents.json --mode collapsed | filter_rows changelog | targets)" \
  "hidden agent-name match"

check "a workspace row resolves to that workspace's active pane"
assert_eq "c|w1|w1:t1|w1:p2" "$(rows mixed-agents.json --mode collapsed | grep '^c|w1' | targets)" \
  "collapsed target of a mixed workspace"

check "a collapsed row matches a child pane's working directory without showing it"
row=$(rows shells-only.json --mode collapsed | grep '^c|w2')
assert_contains "$(cut -f3 <<<"$row" | strip_ansi | cut -c1-120)" "scratch" "visible label"
assert_not_contains "$(cut -f3 <<<"$row" | strip_ansi | cut -c1-120)" "mdbook" "visible columns"
assert_eq "c|w2|w2:t1|w2:p1" \
  "$(rows shells-only.json --mode collapsed | filter_rows mdbook | targets)" \
  "hidden title match"

check "a collapsed row matches a child pane's directory"
assert_eq "c|w2|w2:t1|w2:p1" \
  "$(rows shells-only.json --mode collapsed | filter_rows docs | targets)" \
  "hidden cwd match"

check "a collapsed row resolves to that workspace's active pane"
assert_eq "c|w2|w2:t1|w2:p1" "$(rows shells-only.json --mode collapsed | grep '^c|w2' | targets)" \
  "collapsed row target"

check "the prompt names the active view"
assert_eq "workspaces ▸ " "$(HWM_MODE=collapsed "$REPO_DIR/scripts/prompt.sh")" "collapsed prompt"
assert_eq "panes ▸ " "$(HWM_MODE=expanded "$REPO_DIR/scripts/prompt.sh")" "expanded prompt"
assert_eq "agents ▸ " "$(HWM_MODE=agents "$REPO_DIR/scripts/prompt.sh")" "agents prompt"

check "every mode of a mixed session is reachable and distinct"
assert_eq "3" "$(rows mixed-agents.json --mode collapsed | wc -l | tr -d ' ')" "workspaces view"
assert_eq "6" "$(rows mixed-agents.json --mode expanded | wc -l | tr -d ' ')" "panes view"
assert_eq "4" "$(rows mixed-agents.json --mode agents | wc -l | tr -d ' ')" "agents view"

check "cycling walks collapsed → expanded → agents → collapsed and keeps the location"
run_dir=$(mktemp -d "${TMPDIR:-/tmp}/hwm-mode.XXXXXX")
cp "$REPO_DIR/tests/fixtures/mixed-agents.json" "$run_dir/snapshot.json"
printf 'collapsed' >"$run_dir/mode"

seen=()
for _ in 1 2 3; do
  out=$(HWM_RUN_DIR=$run_dir HWM_WIDTH=120 "$REPO_DIR/scripts/cycle-mode.sh" 'p|w3|w3:t1|w3:p2')
  seen+=("$(<"$run_dir/mode")")
  assert_contains "$out" "reload-sync(" "cycle actions"
  assert_contains "$out" "pos(" "cycle actions"
done
assert_eq "expanded agents collapsed" "${seen[*]}" "mode cycle"

printf 'collapsed' >"$run_dir/mode"
out=$(HWM_RUN_DIR=$run_dir HWM_WIDTH=120 "$REPO_DIR/scripts/cycle-mode.sh" 'p|w3|w3:t1|w3:p2')
position=${out##*pos(}
position=${position%)*}
expected=$(HWM_RUN_DIR=$run_dir HWM_WIDTH=120 "$REPO_DIR/scripts/render.sh" | grep -n '^p|w3|w3:t1|w3:p2' | cut -d: -f1)
assert_eq "$expected" "$position" "selection position after a mode change"
rm -rf "$run_dir"

check "changing view mode never queries the session"
run_dir=$(mktemp -d "${TMPDIR:-/tmp}/hwm-mode.XXXXXX")
cp "$REPO_DIR/tests/fixtures/mixed-agents.json" "$run_dir/snapshot.json"
printf 'expanded' >"$run_dir/mode"
before=$(md5sum <"$run_dir/snapshot.json")
HWM_RUN_DIR=$run_dir HWM_WIDTH=120 HERDR_SOCKET_PATH=/nonexistent.sock \
  "$REPO_DIR/scripts/render.sh" >/dev/null
assert_eq "$before" "$(md5sum <"$run_dir/snapshot.json")" "snapshot untouched by a re-render"
rm -rf "$run_dir"
