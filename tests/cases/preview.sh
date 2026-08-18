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
config_dir=$(mktemp -d "${TMPDIR:-/tmp}/hwm-config.XXXXXX")
cat >"$config_dir/config.toml" <<'CONF'
# workspace-manager
preview = false
preview_size = 35
CONF
read -r enabled size < <(
  HERDR_PLUGIN_CONFIG_DIR=$config_dir bash -c '
    source "'"$REPO_DIR"'/scripts/lib/common.sh"
    hwm_load_config
    printf "%s %s\n" "$HWM_PREVIEW_ENABLED" "$HWM_PREVIEW_SIZE"'
)
assert_eq "0" "$enabled" "preview disabled by configuration"
assert_eq "35" "$size" "preview size from configuration"

check "malformed or absent configuration falls back to defaults"
printf 'preview = ~~~\npreview_size = banana\n[[nonsense\n' >"$config_dir/config.toml"
read -r enabled size < <(
  HERDR_PLUGIN_CONFIG_DIR=$config_dir bash -c '
    source "'"$REPO_DIR"'/scripts/lib/common.sh"
    hwm_load_config
    printf "%s %s\n" "$HWM_PREVIEW_ENABLED" "$HWM_PREVIEW_SIZE"'
)
assert_eq "1" "$enabled" "preview default after malformed configuration"
assert_eq "50" "$size" "preview size default after malformed configuration"

: >"$config_dir/config.toml"
read -r enabled size < <(
  HERDR_PLUGIN_CONFIG_DIR=$config_dir bash -c '
    source "'"$REPO_DIR"'/scripts/lib/common.sh"
    hwm_load_config
    printf "%s %s\n" "$HWM_PREVIEW_ENABLED" "$HWM_PREVIEW_SIZE"'
)
assert_eq "1" "$enabled" "preview default with an empty configuration"

rm -rf "$config_dir" "$run_dir"
printf 'y\n' | HWM_RUN_DIR=/tmp "$REPO_DIR/scripts/close.sh" "c|$pw|$pw:t1|$pane" >/dev/null 2>&1 || true
