# 05 — Preview window

**What to build:** Alongside the list, a preview shows the recent output of whatever row
is highlighted, so two rows that read identically in the list can be told apart before
jumping. The preview works the same way for every row type — there is no rule to learn
about which rows have previews.

For a collapsed workspace row, the preview additionally leads with a short inventory of
the panes inside that workspace, so collapsing never costs information at the moment the
user needs it.

The preview is the only per-selection API call in the finder; the list itself still comes
from a single snapshot. A key toggles the preview off, trading context for a wider list.

**Blocked by:** 02 — Row builder seam.

**Status:** done

- [x] Highlighting a row shows that pane's recent output in a preview window on the right
- [x] Output is rendered with terminal escape sequences stripped and a bounded number of
      lines
- [x] Agent rows, plain pane rows and collapsed workspace rows all produce a preview
      through the same path
- [x] A collapsed workspace row's preview begins with a short inventory of the panes in
      that workspace, followed by the active pane's output
- [x] A key toggles the preview off and on; with it off the list uses the full popup width
- [x] Moving the selection quickly does not stall the list; a slow or failed preview read
      leaves the list responsive
- [x] A preview for a pane that has disappeared renders an explanatory message rather than
      an error dump or empty window
- [x] The list itself issues no additional session queries when the selection moves
