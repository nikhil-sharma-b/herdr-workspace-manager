#!/usr/bin/env bash
# Render the stored snapshot in the stored view mode. No session queries.

set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

run_dir=${HWM_RUN_DIR:?HWM_RUN_DIR is required}
width=${HWM_WIDTH:-200}
mode=collapsed
[[ -f $run_dir/mode ]] && mode=$(<"$run_dir/mode")

[[ -f $run_dir/snapshot.json ]] || exit 0

exec "$script_dir/build-rows.sh" --mode "$mode" --width "$width" <"$run_dir/snapshot.json"
