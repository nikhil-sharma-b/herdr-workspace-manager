#!/usr/bin/env bash
# The preview window — the finder's only per-selection call.
#
# Runs against the isolated server started by run.sh.

printf '\npreview\n'

run_dir=$(mktemp -d "${TMPDIR:-/tmp}/hwm-preview.XXXXXX")

herdr workspace create --label preview-one --cwd "$HOME" --focus >/dev/null
sleep 0.3
pw=$(snapshot | jq -r '.result.snapshot.workspaces[] | select(.label == "preview-one") | .workspace_id')
pane=$(snapshot | jq -r --arg w "$pw" '.result.snapshot.panes[] | select(.workspace_id == $w) | .pane_id' | head -n 1)
herdr pane send-text "$pane" 'echo unmistakable-preview-marker' >/dev/null 2>&1 || true
herdr pane send-keys "$pane" Enter >/dev/null 2>&1 || true
sleep 1

HWM_RUN_DIR=$run_dir HWM_WIDTH=120 "$REPO_DIR/scripts/refresh.sh" >"$run_dir/rows"

check "highlighting a pane row previews that pane's recent output"
out=$(HWM_RUN_DIR=$run_dir "$REPO_DIR/scripts/preview.sh" "p|$pw|$pw:t1|$pane")
assert_contains "$out" "unmistakable-preview-marker" "pane preview"

check "the preview strips terminal escape sequences"
if grep -qE $'\033\\[[0-9;]*[A-Za-z]' <<<"$out"; then
  fail "the preview leaked escape sequences"
fi

check "the preview is bounded in length"
long=$(HWM_RUN_DIR=$run_dir HWM_PREVIEW_LINES=5 "$REPO_DIR/scripts/preview.sh" "p|$pw|$pw:t1|$pane" | wc -l | tr -d ' ')
((long <= 5)) || fail "a preview bounded to 5 lines produced $long"

check "a collapsed workspace row previews its pane inventory before its output"
herdr pane split "$pane" --direction right >/dev/null 2>&1 || true
sleep 0.5
HWM_RUN_DIR=$run_dir HWM_WIDTH=120 "$REPO_DIR/scripts/refresh.sh" >"$run_dir/rows"
collapsed_target=$(grep -m1 "^c|$pw|" "$run_dir/rows" | cut -f1)
[[ -n $collapsed_target ]] || fail "the agent-free workspace did not collapse"
out=$(HWM_RUN_DIR=$run_dir "$REPO_DIR/scripts/preview.sh" "$collapsed_target" | strip_ansi)
assert_contains "$out" "panes in this workspace" "collapsed preview heading"
inventory_line=$(grep -n "panes in this workspace" <<<"$out" | cut -d: -f1)
marker_line=$(grep -n "unmistakable-preview-marker" <<<"$out" | head -n 1 | cut -d: -f1)
if [[ -n $marker_line ]]; then
  ((inventory_line < marker_line)) || fail "the inventory did not come first"
fi

check "every row type previews through the same path"
for target in $(cut -f1 "$run_dir/rows"); do
  out=$(HWM_RUN_DIR=$run_dir "$REPO_DIR/scripts/preview.sh" "$target")
  [[ -n $out ]] || fail "row $target produced an empty preview"
done

check "a pane that has disappeared explains itself instead of erroring"
out=$(HWM_RUN_DIR=$run_dir "$REPO_DIR/scripts/preview.sh" 'p|w999|w999:t1|w999:p1' | strip_ansi)
assert_contains "$out" "gone" "vanished-pane preview"
assert_not_contains "$out" '{"error"' "vanished-pane preview"

check "the list issues no session queries when the selection moves"
before=$(md5sum <"$run_dir/snapshot.json")
HWM_RUN_DIR=$run_dir "$REPO_DIR/scripts/preview.sh" "p|$pw|$pw:t1|$pane" >/dev/null
assert_eq "$before" "$(md5sum <"$run_dir/snapshot.json")" "snapshot after a preview"

# --- configuration ----------------------------------------------------------

check "configuration controls whether the preview shows and how big it is"
# The shipped default is off, so this file asks for it on to prove the file is read.
config_dir=$(mktemp -d "${TMPDIR:-/tmp}/hwm-config.XXXXXX")
cat >"$config_dir/config.toml" <<'CONF'
# workspace-manager
preview = true
preview_size = 35
CONF
read -r enabled size < <(
  HERDR_PLUGIN_CONFIG_DIR=$config_dir bash -c '
    source "'"$REPO_DIR"'/scripts/lib/common.sh"
    hwm_load_config
    printf "%s %s\n" "$HWM_PREVIEW_ENABLED" "$HWM_PREVIEW_SIZE"'
)
assert_eq "1" "$enabled" "preview enabled by configuration"
assert_eq "35" "$size" "preview size from configuration"

check "malformed or absent configuration falls back to defaults"
printf 'preview = ~~~\npreview_size = banana\n[[nonsense\n' >"$config_dir/config.toml"
read -r enabled size < <(
  HERDR_PLUGIN_CONFIG_DIR=$config_dir bash -c '
    source "'"$REPO_DIR"'/scripts/lib/common.sh"
    hwm_load_config
    printf "%s %s\n" "$HWM_PREVIEW_ENABLED" "$HWM_PREVIEW_SIZE"'
)
assert_eq "0" "$enabled" "preview default after malformed configuration"
assert_eq "50" "$size" "preview size default after malformed configuration"

: >"$config_dir/config.toml"
read -r enabled size < <(
  HERDR_PLUGIN_CONFIG_DIR=$config_dir bash -c '
    source "'"$REPO_DIR"'/scripts/lib/common.sh"
    hwm_load_config
    printf "%s %s\n" "$HWM_PREVIEW_ENABLED" "$HWM_PREVIEW_SIZE"'
)
assert_eq "0" "$enabled" "preview default with an empty configuration"

rm -rf "$config_dir" "$run_dir"
printf 'y\n' | HWM_RUN_DIR=/tmp "$REPO_DIR/scripts/close.sh" "c|$pw|$pw:t1|$pane" >/dev/null 2>&1 || true

# --- the preview is off until asked for, and the answer sticks ---------------

preview_setting() {
  HERDR_PLUGIN_CONFIG_DIR=${1:-/nonexistent} HERDR_PLUGIN_STATE_DIR=${2:?} bash -c '
    source "'"$REPO_DIR"'/scripts/lib/common.sh"
    hwm_load_config
    hwm_load_preview_state
    printf "%s" "$HWM_PREVIEW_ENABLED"'
}

check "the preview is off by default"
state=$(mktemp -d "${TMPDIR:-/tmp}/hwm-pstate.XXXXXX")
assert_eq "0" "$(preview_setting /nonexistent "$state")" "default preview setting"

check "toggling records the choice, and the next finder honours it"
HERDR_PLUGIN_STATE_DIR=$state "$REPO_DIR/scripts/toggle-preview.sh"
assert_eq "on" "$(<"$state/preview")" "recorded state after one toggle"
assert_eq "1" "$(preview_setting /nonexistent "$state")" "preview setting after toggling on"

check "toggling back records that too"
HERDR_PLUGIN_STATE_DIR=$state "$REPO_DIR/scripts/toggle-preview.sh"
assert_eq "off" "$(<"$state/preview")" "recorded state after two toggles"
assert_eq "0" "$(preview_setting /nonexistent "$state")" "preview setting after toggling off"

check "a recorded choice outranks the configuration file"
conf=$(mktemp -d "${TMPDIR:-/tmp}/hwm-pconf.XXXXXX")
printf 'preview = false\n' >"$conf/config.toml"
printf 'on' >"$state/preview"
assert_eq "1" "$(preview_setting "$conf" "$state")" "recorded on over configured off"
printf 'preview = true\n' >"$conf/config.toml"
printf 'off' >"$state/preview"
assert_eq "0" "$(preview_setting "$conf" "$state")" "recorded off over configured on"

check "configuration still decides the starting value before anything is toggled"
rm -f "$state/preview"
printf 'preview = true\n' >"$conf/config.toml"
assert_eq "1" "$(preview_setting "$conf" "$state")" "configured on with no record"

check "an unreadable record falls back to the default rather than breaking"
printf 'banana' >"$state/preview"
assert_eq "1" "$(preview_setting "$conf" "$state")" "malformed record keeps the configured value"
rm -rf "$conf" "$state"

check "a popup records the value it opened with, so the first toggle flips correctly"
state=$(mktemp -d "${TMPDIR:-/tmp}/hwm-pseed.XXXXXX")
conf=$(mktemp -d "${TMPDIR:-/tmp}/hwm-pseedconf.XXXXXX")
printf 'preview = true\n' >"$conf/config.toml"
HERDR_PLUGIN_CONFIG_DIR=$conf HERDR_PLUGIN_STATE_DIR=$state bash -c '
  source "'"$REPO_DIR"'/scripts/lib/common.sh"
  hwm_load_config
  hwm_load_preview_state
  hwm_record_preview_state'
assert_eq "on" "$(<"$state/preview")" "state recorded when the config opens the preview"
HERDR_PLUGIN_STATE_DIR=$state "$REPO_DIR/scripts/toggle-preview.sh"
assert_eq "off" "$(<"$state/preview")" "first toggle turns a configured-on preview off"
rm -rf "$state" "$conf"
