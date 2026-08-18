# 04 — View modes: collapse, expand, agents-only

**What to build:** The list stops drowning in identical shell panes. A workspace whose
panes contain no agents renders as a single row instead of one row per shell. Nothing
becomes unreachable by doing so: the collapsed row still matches when the user types the
working directory or terminal title of any pane inside it, and selecting it lands on that
workspace's active pane.

One key cycles between three views — collapsed, fully expanded (every pane, as built in
ticket 02), and agents-only — so the user can widen or narrow without leaving the finder.
The active view is shown in the finder's prompt, so it is never ambiguous which of the
three lists is on screen.

**Blocked by:** 02 — Row builder seam.

**Status:** done

- [x] Every workspace renders as exactly one row in the default view
- [x] A collapsed row matches queries drawn from any of its child panes' working
      directories or terminal titles, without displaying them
- [x] Selecting a collapsed row focuses that workspace and its active pane
- [x] A workspace containing agents is one row too, naming its agent or counting them, and
      taking its status from the workspace
- [x] One key cycles collapsed → expanded → agents-only → collapsed
- [x] The expanded view shows one row per pane, matching ticket 02's behaviour
- [x] The agents-only view shows only panes with a detected agent
- [x] The active view mode is displayed in the finder prompt
- [x] Changing view mode does not re-query the session; it re-renders the existing
      snapshot
- [x] The selection stays on the same underlying location across a mode change where that
      location is still visible
- [x] Fixture tests cover all three modes for: a session of only shells, a session of only
      agents, and a mixed session where one workspace has both

**Clarified after review:** "workspaces containing agents are not collapsed" was first read
as "such a workspace contributes one row per pane", which put two rows for the same
workspace and tab in the default view. Settled with the user the other way: the collapsed
view lists workspaces only. Agent panes are reached through the agents view, and remain
searchable from the workspace row through hidden fields.
