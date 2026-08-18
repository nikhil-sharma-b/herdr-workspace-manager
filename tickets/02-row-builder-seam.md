# 02 — Row builder seam

**What to build:** The finder lists one row per navigable pane rather than one row per
workspace, and each row carries everything the user might remember about that location:
workspace number, workspace label, tab label, agent kind and agent name, agent status,
working directory, and the pane's terminal title. All of it is fuzzy-searchable, so
typing part of an agent's name, part of a repository path, or part of what a pane is
currently running all reach the same place.

Row construction becomes the project's primary test seam: a standalone transformation
that takes a session snapshot document on standard input and emits rendered rows on
standard output. The finder consumes that output. This makes every subsequent rendering
decision testable from fixtures, with no server and no interactive terminal.

Rows carry a stable target identifier so the handoff from ticket 01 continues to work
unchanged, and may carry fields that are searchable but not displayed.

**Blocked by:** 01 — Walking skeleton: key → popup → jump.

**Status:** done

- [x] Row construction is a standalone component: snapshot document in, rendered rows out
- [x] The finder builds its list by feeding a single session snapshot through that
      component
- [x] One row per pane, ordered by workspace number, then by a stable order within a
      workspace
- [x] Each row includes workspace number, workspace label, tab label, agent kind, agent
      name, agent status, working directory and pane terminal title, omitting cleanly
      whichever of those the session does not provide for that pane
- [x] Panes with no agent still produce rows
- [x] Every field is part of the fuzzy match haystack, including fields that are not
      displayed
- [x] Each row resolves to the identifiers the focus routine needs, and selecting any row
      focuses that exact pane
- [x] Fixture-driven tests cover: a session with no agents, a session with several agents
      across several workspaces, a workspace with multiple tabs, a pane with a missing
      working directory or title, and a session with a single workspace
- [x] Non-interactive filter tests prove a query matching only an agent name, only a
      working directory, or only a terminal title selects the expected row
- [x] Row output is stable enough to assert on: same snapshot in, byte-identical rows out
