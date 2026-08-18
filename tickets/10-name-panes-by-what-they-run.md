# 10 — Name panes by what they are running

**What to build:** A pane's row is named for the program in it. A pane running `lazygit`
says `lazygit`; one running `nvim src/handler.rs` says so, arguments included, so two
editors on different files stay apart. A pane sitting idle at its shell prompt keeps the
terminal title instead, because naming every idle pane `fish` names none of them.

This came out of using the finder: the session snapshot carries no notion of what a pane
is doing, and `terminal_title` is whatever the shell decided to set. Under fish that is the
working directory, so every pane in one repository was titled `/h/d/r/chat` — the column
that was supposed to tell panes apart told the user nothing.

Learning what a pane runs costs one request per pane, so a refresh is no longer a single
request. That is accepted: it is paid on open, on refresh and after a mutation, never while
the user types or moves the selection. The row builder stays a pure transformation — the
per-pane lookups happen during collection, and rows are still built from one document.

Nothing is written to the session. The names exist in the finder; herdr's own sidebar and
tab bar are untouched. Renaming herdr's real panes was considered and declined: keeping
such names honest needs a background watcher, which is the deferred v2 daemon.

**Blocked by:** 02 — Row builder seam.

**Status:** done

- [x] A pane running a program is named for that program, with its arguments
- [x] A pane idling at its shell prompt falls back to the terminal title rather than being
      named after the shell
- [x] A name set with `herdr pane rename` outranks both
- [x] Every candidate name stays searchable, whichever one is displayed, so a renamed pane
      is still findable by what it is running
- [x] A workspace row matches a program running in any of its panes
- [x] The preview's pane inventory names panes the same way
- [x] Snapshots carrying no process information still render, unchanged
- [x] The row builder remains a pure document transformation, testable from fixtures that
      describe a pane running anything
- [x] The session is never modified
- [x] Fixture tests cover a running program, a program with arguments, an idle shell, a
      renamed pane and a pane with no process record; a live test covers a real program
      running in a real pane
