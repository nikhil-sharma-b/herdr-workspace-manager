# 03 — Row presentation: status glyphs, focus marker, worktree labels

**What to build:** The list becomes readable at a glance. Every agent's status is a
colored glyph, so a blocked agent waiting on an approval is the first thing the eye
lands on, and an agent that finished work the user has not looked at yet is visibly
different from one merely sitting idle — that distinction is usually the reason the
finder was opened at all. The location the user is currently in is marked, so the list
reads as "where I am versus where I could go".

Workspaces that are linked worktree checkouts stop being indistinguishable. They render
with their repository name and their checkout name plus a marker identifying them as
worktrees, and both halves are searchable. This is the case where a name-only picker
performs worst, and where this plugin should feel obviously better than the built-in one.

Colors come from the terminal's ANSI palette, never fixed RGB values, so the finder
follows whatever theme is active.

**Blocked by:** 02 — Row builder seam.

**Status:** done

- [x] Each agent row shows a status glyph colored by status: blocked red, working yellow,
      done green, idle dim, unknown dim
- [x] Done and idle use visually distinct glyphs, not merely distinct colors
- [x] The currently focused location is marked with a leading indicator
- [x] Linked worktree workspaces display repository name, checkout name and a worktree
      marker
- [x] Both the repository name and the checkout name match when typed
- [x] Non-worktree workspaces are unaffected and keep their plain label
- [x] All colors are ANSI palette entries; no RGB escape sequences appear in output
- [x] Rows remain aligned in columns when glyph and status widths vary
- [x] Fixture tests cover each status value, the focused marker, a linked worktree
      workspace, a primary checkout of the same repository, and several worktrees of one
      repository appearing together
- [x] Output remains assertable: colors and glyphs are deterministic for a given snapshot
