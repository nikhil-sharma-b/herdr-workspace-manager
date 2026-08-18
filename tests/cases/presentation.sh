#!/usr/bin/env bash
# Status glyphs, the focus marker, worktree labels and colour discipline.

printf '\npresentation\n'

glyph_of() {
  local target=$1 fixture=$2
  rows "$fixture" --mode expanded | grep "^$target" | cut -f3 | strip_ansi | cut -c3
}

# The escape sequence immediately preceding the status glyph.
colour_of() {
  local target=$1 fixture=$2
  rows "$fixture" --mode expanded | grep "^$target" | cut -f3 |
    sed -E $'s/^.*\033\\[([0-9;]*)m(●|◐|✔|·|○).*$/\\1/' |
    { read -r code; printf $'\033[%sm' "$code"; }
}

check "blocked renders red"
assert_eq $'\033[31m' "$(colour_of 'p|w1|w1:t1|w1:p2' mixed-agents.json)" "blocked colour"

check "working renders yellow"
assert_eq $'\033[33m' "$(colour_of 'p|w3|w3:t1|w3:p1' mixed-agents.json)" "working colour"

check "done renders green"
assert_eq $'\033[32m' "$(colour_of 'p|w3|w3:t1|w3:p2' mixed-agents.json)" "done colour"

check "idle renders dim"
assert_eq $'\033[2m' "$(colour_of 'p|w3|w3:t1|w3:p3' mixed-agents.json)" "idle colour"

check "unknown renders dim"
assert_eq $'\033[2m' "$(colour_of 'p|w2|w2:t1|w2:p1' mixed-agents.json)" "unknown colour"

check "done and idle use distinct glyphs, not merely distinct colours"
done_glyph=$(glyph_of 'p|w3|w3:t1|w3:p2' mixed-agents.json)
idle_glyph=$(glyph_of 'p|w3|w3:t1|w3:p3' mixed-agents.json)
[[ -n $done_glyph && $done_glyph != "$idle_glyph" ]] ||
  fail "done [$done_glyph] and idle [$idle_glyph] share a glyph"

check "every status has its own glyph"
blocked_glyph=$(glyph_of 'p|w1|w1:t1|w1:p2' mixed-agents.json)
working_glyph=$(glyph_of 'p|w3|w3:t1|w3:p1' mixed-agents.json)
distinct=$(printf '%s\n%s\n%s\n%s\n' "$blocked_glyph" "$working_glyph" "$done_glyph" "$idle_glyph" | sort -u | wc -l)
assert_eq "4" "$(echo "$distinct" | tr -d ' ')" "distinct glyph count"

check "the focused location is marked and nothing else is"
marked=$(rows mixed-agents.json --mode expanded | cut -f1,3 | strip_ansi | awk -F '\t' '$2 ~ /^◆/ { print $1 }')
assert_eq "p|w1|w1:t1|w1:p2" "$marked" "focus marker"

check "no RGB escape sequences appear anywhere"
for fixture in shells-only.json mixed-agents.json worktrees.json sparse.json; do
  for mode in collapsed expanded agents; do
    if rows "$fixture" --mode "$mode" | grep -qE $'\033\\[[0-9;]*(38|48);2'; then
      fail "$fixture/$mode emits a truecolor escape"
    fi
  done
done

check "rows stay aligned when glyph and status widths vary"
widths=$(rows mixed-agents.json --mode expanded | cut -f3 | strip_ansi |
  awk '{ print index($0, "~/src") }' | sort -u | wc -l)
assert_eq "1" "$(echo "$widths" | tr -d ' ')" "column alignment"

# --- worktrees --------------------------------------------------------------

check "linked worktree workspaces show repository, checkout and a marker"
row=$(rows worktrees.json --mode expanded | grep '^p|w2' | cut -f3 | strip_ansi)
assert_contains "$row" "kettle ⑂ audit-logs" "worktree label"

check "several worktrees of one repository stay distinguishable"
labels=$(rows worktrees.json --mode expanded | cut -f3 | strip_ansi | grep -oE 'kettle ⑂ [a-z-]+' | sort -u | paste -sd ',' -)
assert_eq "kettle ⑂ audit-logs,kettle ⑂ retry-backoff" "$labels" "worktree labels"

check "the primary checkout keeps its plain label"
row=$(rows worktrees.json --mode expanded | grep '^p|w1' | cut -f3 | strip_ansi)
assert_not_contains "$row" "⑂" "primary checkout label"

check "non-worktree workspaces are unaffected"
row=$(rows worktrees.json --mode expanded | grep '^p|w4' | cut -f3 | strip_ansi)
assert_contains "$row" "plain" "plain workspace label"
assert_not_contains "$row" "⑂" "plain workspace label"

check "a worktree workspace matches on its repository name"
assert_contains "$(rows worktrees.json --mode expanded | filter_rows kettle | targets | paste -sd ' ' -)" \
  "p|w2|w2:t1|w2:p1" "repository-name match"

check "a worktree workspace matches on its checkout name"
assert_eq "p|w3|w3:t1|w3:p1" \
  "$(rows worktrees.json --mode expanded | filter_rows retrybackoff | targets)" \
  "checkout-name match"
