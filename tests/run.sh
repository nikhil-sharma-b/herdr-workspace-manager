#!/usr/bin/env bash
# The suite. One entry point: ./tests/run.sh
#
# Fixture cases need nothing but jq, fzf and bash. Live cases run against a
# herdr server this script starts on a private socket with a private HOME, so
# the suite can neither read nor write the developer's session state.

set -uo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export REPO_DIR

# shellcheck source=lib/harness.sh
source "$REPO_DIR/tests/lib/harness.sh"

if [[ -z $HERDR_BIN ]]; then
  printf 'herdr is not on PATH; set HERDR_BIN to run the live cases\n' >&2
  exit 1
fi

for tool in jq fzf; do
  command -v "$tool" >/dev/null 2>&1 || {
    printf '%s is required to run the suite\n' "$tool" >&2
    exit 1
  }
done

printf 'syntax\n'
for script in "$REPO_DIR"/scripts/*.sh "$REPO_DIR"/scripts/lib/*.sh "$REPO_DIR"/tests/*.sh "$REPO_DIR"/tests/lib/*.sh "$REPO_DIR"/tests/cases/*.sh; do
  check "$(basename "$script") parses"
  bash -n "$script" || fail "syntax error"
done
check "the row builder's jq program compiles"
jq -n --arg mode collapsed --arg home "" --argjson width 120 -f "$REPO_DIR/scripts/lib/rows.jq" \
  <<<'{}' >/dev/null 2>&1 || jq -n --arg mode collapsed --arg home "" --argjson width 120 \
  -f "$REPO_DIR/scripts/lib/rows.jq" >/dev/null || fail "rows.jq does not compile"

check "the manifest is valid TOML declaring a popup finder"
grep -q 'placement = "popup"' "$REPO_DIR/herdr-plugin.toml" || fail "no popup placement in the manifest"
grep -q 'min_herdr_version' "$REPO_DIR/herdr-plugin.toml" || fail "no minimum herdr version in the manifest"

# --- fixture cases ----------------------------------------------------------

for case_file in rows presentation view-modes; do
  # shellcheck source=/dev/null
  source "$REPO_DIR/tests/cases/$case_file.sh"
done

# --- live cases -------------------------------------------------------------

REAL_HOME=$HOME
trap 'stop_isolated_herdr' EXIT INT TERM
start_isolated_herdr

if [[ $HOME == "$REAL_HOME" ]]; then
  printf 'refusing to run live cases against the real home directory\n' >&2
  exit 1
fi

for case_file in live preview failures; do
  # shellcheck source=/dev/null
  source "$REPO_DIR/tests/cases/$case_file.sh"
done

stop_isolated_herdr
trap - EXIT INT TERM

printf '\n'
if ((TESTS_FAILED > 0)); then
  printf '\033[31m%d of %d checks failed\033[0m\n' "$TESTS_FAILED" "$TESTS_RUN"
  exit 1
fi
printf '\033[32mall %d checks passed\033[0m\n' "$TESTS_RUN"
