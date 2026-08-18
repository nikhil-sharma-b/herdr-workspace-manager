# 01 — Walking skeleton: key → popup → jump

**What to build:** Pressing a bound key inside herdr opens a floating popup containing a
fuzzy finder listing every workspace in the session. Typing filters the list. Pressing
Enter closes the popup and lands the session on the selected workspace. Pressing Esc
closes the popup and changes nothing. Pressing the refresh key re-reads the session and
redraws the list without closing the popup.

This is the tracer bullet: it deliberately cuts through every layer at once — plugin
manifest, action process, popup pane, snapshot read, finder UI, handoff, focus, and the
test harness — because none of the later tickets are demoable until this path exists end
to end. Rows are intentionally crude here (workspace number and label only); everything
that makes rows rich is ticket 02 onward.

The plugin is a herdr plugin proper: a manifest at the repository root declaring the
plugin id, the minimum herdr version, one action (the thing the user binds) and one pane
entrypoint declared with popup placement and percentage geometry. Popup placement and
geometry must live in the manifest — the CLI cannot request popup placement.

The action process runs outside the popup, so it is the component that performs focus
after the popup has closed. It mints a per-invocation correlation id, opens the finder
pane passing the choice-file path through the environment, waits for that pane to close,
reads the choice file, and focuses workspace then tab then pane. An absent or empty
choice file means the user aborted and nothing happens.

The finder runs inside the popup: one session snapshot per refresh, rows built from that
single document, no API calls while the user types or moves the selection.

Installation for this ticket is by linking the local checkout.

**Blocked by:** None — can start immediately.

**Status:** done

- [x] Manifest at repo root declares plugin id `workspace-manager`, the minimum herdr
      version, an `open` action, and a `finder` pane entrypoint with popup placement and
      percentage width/height
- [x] Linking the local checkout registers the plugin and its action and pane entrypoint
      are visible in herdr's plugin listing
- [x] A documented key binding of type `plugin_action` invokes the `open` action
- [x] Invoking the action opens a bordered floating popup that does not disturb the
      existing pane layout
- [x] The popup lists one row per workspace showing workspace number and label, in
      workspace number order
- [x] Typing filters rows fuzzily; multi-select is disabled
- [x] Enter writes the chosen target to the per-invocation choice file and exits, the
      popup closes, and the session is then focused on the chosen workspace, its active
      tab, and its active pane
- [x] Focus is performed by the action process after the popup has closed, never from
      inside the popup
- [x] Esc leaves the session exactly as it was: same focused workspace, tab and pane
- [x] The refresh key re-reads the session snapshot and redraws the list without closing
      the popup
- [x] Exactly one snapshot request is issued per open and per refresh, and none while
      typing or moving the selection
- [x] The choice file is removed after the action process reads it
- [x] A test harness stands up a headless herdr server on a private socket with private
      configuration and state locations, and never reads or writes the developer's live
      session
- [x] A test creates several workspaces against that isolated server and asserts that the
      focus routine lands on the intended workspace, tab and pane
- [x] The test suite runs from a single documented entry point and passes
