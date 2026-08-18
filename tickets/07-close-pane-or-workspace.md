# 07 — Close pane or workspace

**What to build:** Tidying up stops requiring a visit to each workspace. A key closes the
thing the highlighted row represents: a pane row closes that pane, a collapsed workspace
row closes that workspace. The key does what the row on screen implies, so there is
nothing to remember.

Because this is the only part of the finder that can destroy running work, it is gated.
Every close asks for confirmation first. Closing the last remaining workspace is refused
outright, so the session cannot be emptied out from under the user. When herdr itself
warns that a close would tear down a worktree group, that warning is surfaced as a second,
explicit confirmation rather than auto-confirmed or swallowed.

After a successful close the list reflects reality immediately.

**Blocked by:** 04 — View modes: collapse, expand, agents-only.

**Status:** done

- [x] A key initiates close on the highlighted row
- [x] A pane row closes that pane; a collapsed workspace row closes that workspace
- [x] Every close asks for confirmation, defaulting to "no"
- [x] Declining the confirmation closes nothing and returns to the list with the selection
      intact
- [x] Attempting to close the last remaining workspace is refused with an explanatory
      message and closes nothing
- [x] When herdr responds that the close requires confirmation because it would close a
      worktree group, the user is shown that reason and asked a second, explicit time
- [x] Declining the second confirmation leaves the worktree group intact
- [x] After a successful close the list refreshes and the closed row is gone
- [x] Closing the pane the user is currently focused on leaves the session in a valid
      focused state
- [x] A failed close reports the failure and leaves the finder usable
- [x] Tests against the isolated server cover: closing a pane, closing a workspace,
      refusing the last workspace, declining a confirmation, and the finder's state after
      each

**Implementation note:** herdr's `workspace.close` / `pane.close` take no force flag, and
closing a worktree source workspace tears the whole group down *without* returning
`confirmation_required`. The second confirmation is therefore raised by the plugin itself,
before the call, naming the worktree workspaces that will go with it. A
`confirmation_required` response from herdr is surfaced verbatim and stops, because there
is no way to confirm through it.
