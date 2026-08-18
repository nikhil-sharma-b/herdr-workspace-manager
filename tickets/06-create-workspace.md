# 06 — Create workspace

**What to build:** When the thing the user is searching for does not exist yet, creating
it is one key away instead of a trip out of the finder. A key prompts for a name and
creates a workspace whose working directory is inherited from the row that was
highlighted — because the reason the finder was open is that the user was already
thinking about that repository. Submitting an empty name accepts herdr's default label.

Creation is not a dead end: the new workspace becomes the focused one, so creating and
switching are a single action.

**Blocked by:** 04 — View modes: collapse, expand, agents-only.

**Status:** done

- [x] A key opens a name prompt inside the popup without disturbing the session
- [x] Submitting a name creates a workspace with that label
- [x] Submitting an empty name creates a workspace with herdr's default label
- [x] The new workspace's working directory is the working directory of the row that was
      highlighted when the key was pressed
- [x] Creating from a collapsed workspace row uses that workspace's active pane's working
      directory
- [x] Cancelling the prompt creates nothing and returns to the list with the selection
      intact
- [x] After creation the session lands on the new workspace
- [x] If creation fails, the failure is reported and the finder remains usable
- [x] A test against the isolated server asserts a workspace is created with the expected
      label and working directory, and that focus lands on it
