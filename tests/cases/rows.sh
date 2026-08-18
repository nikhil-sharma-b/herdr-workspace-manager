#!/usr/bin/env bash
# Row builder: snapshot fixtures in, rendered rows out. No server, no terminal.

printf '\nrow builder\n'

# --- one row per pane, ordered by workspace number then tab -----------------

check "expanded view lists one row per pane in workspace order"
assert_eq \
  "p|w1|w1:t1|w1:p1 p|w2|w2:t1|w2:p1 p|w2|w2:t1|w2:p2 p|w2|w2:t2|w2:p3 p|w3|w3:t1|w3:p1" \
  "$(rows shells-only.json --mode expanded | targets | paste -sd ' ' -)" \
  "row order"

check "panes with no agent still produce rows"
assert_eq "5" "$(rows shells-only.json --mode expanded | wc -l | tr -d ' ')" "pane row count"

check "a session with a single workspace renders that workspace"
assert_eq "2" "$(rows sparse.json --mode expanded | wc -l | tr -d ' ')" "sparse row count"

# --- every field displayed, missing fields omitted cleanly ------------------

check "a row carries workspace, tab, agent, status, cwd and title"
row=$(rows mixed-agents.json --mode expanded | grep '^p|w1|w1:t1|w1:p2' | strip_ansi)
assert_contains "$row" "kettle" "workspace label"
assert_contains "$row" "main" "tab label"
assert_contains "$row" "claude" "agent kind"
assert_contains "$row" "kettle-refactor" "agent name"
assert_contains "$row" "~/src/kettle" "working directory"

check "a pane with no cwd or title renders without breaking the row"
row=$(rows sparse.json --mode expanded | grep '^p|w1|w1:t1|w1:p1' | strip_ansi)
assert_contains "$row" "only" "workspace label"
assert_not_contains "$row" "null" "row"

# --- the fuzzy haystack -----------------------------------------------------

check "a query matching only an agent name selects that row"
assert_eq "p|w1|w1:t1|w1:p2" \
  "$(rows mixed-agents.json --mode expanded | filter_rows refactor | targets)" \
  "agent-name match"

check "a query matching only a working directory selects that row"
assert_eq "p|w2|w2:t1|w2:p1" \
  "$(rows mixed-agents.json --mode expanded | filter_rows handbook | targets)" \
  "cwd match"

check "a query matching only a terminal title selects that row"
assert_eq "p|w2|w2:t2|w2:p3" \
  "$(rows shells-only.json --mode expanded | filter_rows mdbook | targets)" \
  "terminal-title match"

check "a query matching only an agent kind selects that tool's sessions"
assert_eq "p|w3|w3:t1|w3:p1" \
  "$(rows mixed-agents.json --mode agents | filter_rows codex | targets)" \
  "agent-kind match"

check "target identifiers are never part of the haystack by accident"
assert_eq "" "$(rows shells-only.json --mode expanded | filter_rows zzzznothing | targets)" \
  "nonsense query"

# --- stability --------------------------------------------------------------

check "the same snapshot renders byte-identical rows"
first=$(rows mixed-agents.json --mode expanded | md5sum)
second=$(rows mixed-agents.json --mode expanded | md5sum)
assert_eq "$first" "$second" "row digest"

check "rows resolve to the identifiers the focus routine needs"
while IFS= read -r target; do
  [[ $target =~ ^[pc]\|w[0-9]+\|w[0-9]+:t[0-9]+\|w[0-9]+:p[0-9]+$ ]] ||
    fail "malformed target [$target]"
done < <(rows mixed-agents.json --mode expanded | targets)
