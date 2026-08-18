# Row builder: session snapshot in, finder rows out.
#
# Emits one tab-separated row per navigable location:
#
#   1  target    <kind>|<workspace_id>|<tab_id>|<pane_id>   (kind: p | c)
#   2  cwd       working directory the row represents
#   3  display   rendered, ANSI-coloured, padded to $width, followed by the
#                hidden haystack — everything searchable that the visible
#                columns truncate or never show. fzf matches the whole field
#                and renders only what fits, so the hidden tail is searchable
#                without being visible (see finder.sh, --ellipsis='').
#
# Parameters: $mode (collapsed|expanded|agents), $width, $home.

def ESC: "\u001b[";
def SGR(n): ESC + n + "m";
def RESET: SGR("0");
def DIM: SGR("2");
def BOLD: SGR("1");
def RED: SGR("31");
def GREEN: SGR("32");
def YELLOW: SGR("33");
def BLUE: SGR("34");
def MAGENTA: SGR("35");
def CYAN: SGR("36");

def spaces($n): if $n > 0 then ($n * " ") else "" end;

# Truncate to $n columns with an ellipsis, or pad to exactly $n columns.
def fit($n):
  (. // "") as $s
  | if $n <= 0 then ""
    elif ($s | length) > $n then ($s[0:$n - 1] + "…")
    else $s + spaces($n - ($s | length))
    end;

def rpad($n): (. // "") | (if ($n - length) > 0 then spaces($n - length) else "" end) + .;

def glyph($status):
  {"blocked": "●", "working": "◐", "done": "✔", "idle": "·", "unknown": "○"}[$status] // "○";

def glyph_colour($status):
  {"blocked": RED, "working": YELLOW, "done": GREEN, "idle": DIM, "unknown": DIM}[$status] // DIM;

def shorten_home:
  (. // "") as $p
  | if ($home != "" and ($p | startswith($home))) then "~" + $p[($home | length):] else $p end;

def basename: (. // "") | split("/") | map(select(. != "")) | (last // "");

def clean: (. // "") | gsub("[\t\r\n]"; " ") | gsub(" +"; " ") | sub("^ +"; "") | sub(" +$"; "");

# ---------------------------------------------------------------------------

. as $snap
| ($snap.focused_pane_id // "") as $focused_pane
| ($snap.focused_workspace_id // "") as $focused_workspace
| (reduce ($snap.agents // [])[] as $a ({}; .[$a.pane_id] = $a)) as $agents
| (reduce ($snap.tabs // [])[] as $t ({}; .[$t.tab_id] = $t)) as $tabs
| (reduce ($snap.workspaces // [])[] as $w ({}; .[$w.workspace_id] = $w)) as $workspaces

# Column widths, allocated from the popup's real width so that the hidden
# haystack always starts past the right edge.
| ($width - 8) as $room
| ([14, (($room * 24 / 100) | floor)] | max) as $w_label
| 8 as $w_tab
| ([10, (($room * 20 / 100) | floor)] | max) as $w_agent
| ([10, (($room * 24 / 100) | floor)] | max) as $w_title
| ([8, ($room - $w_label - $w_tab - $w_agent - $w_title - 4)] | max) as $w_cwd

| [ ($snap.panes // []) | to_entries[] | .key as $ord | .value | {pane: ., ord: $ord} ] as $panes

# Attach the workspace, tab, agent and ordering keys each row needs.
| [ $panes[]
    | .pane as $p
    | ($workspaces[$p.workspace_id] // null) as $ws
    | select($ws != null)
    | ($tabs[$p.tab_id] // null) as $tab
    | ($agents[$p.pane_id] // null) as $agent
    | {
        pane: $p,
        ws: $ws,
        tab: $tab,
        agent: $agent,
        ord: .ord,
        ws_number: ($ws.number // 0),
        tab_number: ($tab.number // 0),
        status: ($agent.agent_status // $p.agent_status // "unknown"),
        cwd: ($p.foreground_cwd // $p.cwd // ""),
        title: ($p.terminal_title_stripped // $p.terminal_title // "" | clean)
      }
  ] as $entries

# Workspace label: linked worktree checkouts render as repo + checkout so that
# four checkouts of one repo are distinguishable; everything else keeps its
# plain label.
| def ws_label($ws):
    if ($ws.worktree != null and $ws.worktree.is_linked_worktree == true)
    then ($ws.worktree.repo_name // "?") + " ⑂ " + ($ws.worktree.checkout_path | basename)
    else ($ws.label // "")
    end;

def ws_haystack($ws):
    [$ws.label]
    + (if $ws.worktree != null
       then [$ws.worktree.repo_name, ($ws.worktree.checkout_path | basename), $ws.worktree.checkout_path, $ws.worktree.repo_root]
       else [] end)
    | map(select(. != null and . != "")) | unique | join(" ");

def agent_text($e):
    if $e.agent == null then ""
    else [($e.agent.agent // $e.agent.display_agent // ""), ($e.agent.name // "")]
         | map(select(. != null and . != "")) | join(" ")
    end;

# One rendered row. $kind is "p" (a pane) or "c" (a collapsed workspace).
def render($kind; $e; $tab_text; $agent_text; $title; $extra_haystack):
    ($e.ws) as $ws
    | ($kind == "c") as $collapsed
    | (if $collapsed
       then ($ws.workspace_id == $focused_workspace)
       else ($e.pane.pane_id == $focused_pane) end) as $is_focused
    | ($e.status) as $status
    | ($e.cwd | shorten_home) as $short_cwd
    | (if $is_focused then "◆" else " " end) as $marker
    | ((($ws.number // 0) | tostring) | rpad(3)) as $number
    | (ws_label($ws)) as $label
    | ([$marker, " ", (glyph($status)), " ", $number, " ",
        ($label | fit($w_label)), " ",
        ($tab_text | fit($w_tab)), " ",
        ($agent_text | fit($w_agent)), " ",
        ($title | clean | fit($w_title)), " ",
        ($short_cwd | fit($w_cwd))] | join("")) as $plain
    | ([(if $is_focused then BOLD + BLUE + $marker + RESET else $marker end), " ",
        (glyph_colour($status)), (glyph($status)), RESET, " ",
        DIM, $number, RESET, " ",
        (if $is_focused then BOLD else "" end), ($label | fit($w_label)), RESET, " ",
        DIM, ($tab_text | fit($w_tab)), RESET, " ",
        CYAN, ($agent_text | fit($w_agent)), RESET, " ",
        ($title | clean | fit($w_title)), " ",
        DIM, ($short_cwd | fit($w_cwd)), RESET] | join("")) as $coloured
    | ([ws_haystack($ws), ($e.tab.label // ""), $agent_text, $status, $e.cwd, $title, $extra_haystack]
       | map(select(. != null and . != "")) | join(" ") | clean) as $haystack
    | [ ($kind + "|" + $ws.workspace_id + "|" + ($e.pane.tab_id // $ws.active_tab_id // "") + "|" + ($e.pane.pane_id // "")),
        $e.cwd,
        ($coloured + spaces([1, ($width - ($plain | length))] | max) + $haystack)
      ] | join("\t");

# The pane a collapsed workspace row stands for: the focused pane of its active
# tab, else that tab's first pane, else the workspace's first pane.
def active_entry($group):
    ($group[0].ws.active_tab_id // "") as $active_tab
    | ([$group[] | select(.pane.tab_id == $active_tab)]) as $in_tab
    | (if ($in_tab | length) > 0 then $in_tab else $group end) as $candidates
    | ([$candidates[] | select(.pane.focused == true)] | first) // ($candidates | first);

($entries | sort_by(.ws_number, .tab_number, .ord)) as $sorted

| if $mode == "expanded" then
    [ $sorted[]
      | render("p"; .; (.tab.label // ""); agent_text(.); .title; "") ]
  elif $mode == "agents" then
    [ $sorted[] | select(.agent != null)
      | render("p"; .; (.tab.label // ""); agent_text(.); .title; "") ]
  else
    # collapsed: exactly one row per workspace, whatever is inside it. Panes and
    # agents have their own views; this one answers "which workspace?" and
    # nothing else. Everything inside stays searchable through hidden fields.
    [ $sorted
      | group_by(.ws_number)[]
      | . as $group
      | ($group[0].ws) as $ws
      | active_entry($group) as $rep
      | ([$group[] | select(.agent != null)]) as $agent_entries
      | ([$group[] | .cwd, .title, (.tab.label // ""), agent_text(.)]
         | map(select(. != null and . != "")) | unique | join(" ")) as $children
      | (if ($agent_entries | length) == 0 then ""
         elif ($agent_entries | length) == 1 then agent_text($agent_entries[0])
         else (($agent_entries | length | tostring) + " agents")
         end) as $agents_text
      | render("c"; ($rep | .status = ($ws.agent_status // $rep.status));
               (($ws.tab_count // 1 | tostring) + "t·" + ($ws.pane_count // ($group | length) | tostring) + "p");
               $agents_text;
               (if ($group | length) == 1 then $rep.title else (($group | length | tostring) + " panes") end);
               $children) ]
  end
| .[]
