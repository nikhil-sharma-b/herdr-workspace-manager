#!/usr/bin/env bash
# fzf `transform` hook run straight after create.sh.
#
# A workspace was created: leave the finder so the action process can focus it.
# Nothing was created: stay, and refresh in case the session changed anyway.

set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
run_dir=${HWM_RUN_DIR:?HWM_RUN_DIR is required}

if [[ -s $run_dir/pending_target ]]; then
  printf 'abort'
else
  printf 'reload(%s/refresh.sh)' "$script_dir"
fi
