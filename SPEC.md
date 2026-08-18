# herdr-workspace-manager — v1 spec

A herdr plugin that opens a floating fuzzy finder over every workspace, tab, pane and
agent in the current herdr session, and jumps to the selected one.

## Problem Statement

herdr already lists workspaces and agent sessions in the sidebar, and ships a workspace
picker on `prefix+w` plus a `goto` on `prefix+g`. Navigation is still slow:

- The built-in picker is arrow-scroll only. There is no fuzzy match, so reaching the
  eleventh workspace means eleven keypresses, not four keystrokes.
- It is workspace-granular. When several agent sessions are running, there is no way to
  type part of an agent's name, its working directory, or what it is running and land on
  that pane.
- The only fast path to a specific pane today is naming panes by hand and binding keys to
  them. That is manual bookkeeping the user has to do up front, for every pane, before the
  pane is useful.
- Linked worktree checkouts of the same repo produce workspaces with near-identical
  labels, which is exactly the case where a name-only, scroll-only picker performs worst.

## Solution

A herdr plugin, `workspace-manager`, that binds a key to a floating popup pane containing
an `fzf` finder. The finder lists one row per navigable location in the session —
workspaces, tabs, panes, agents — with agent status, working directory, worktree/branch
information, and the pane's terminal title, all of it fuzzy-searchable. A live preview of
the highlighted pane's output sits alongside the list. `Enter` focuses the chosen
location; the popup closes and the session lands there. The finder also creates and closes
workspaces and panes so the common cases never require leaving it.

The plugin models itself on the user's `tmux-session-finder`: one snapshot at open, no
queries while typing, ANSI colors that follow the active terminal theme, and the same
`Ctrl-n` / `Ctrl-x` / `Ctrl-r` key vocabulary.

## User Stories

1. As a herdr user with a dozen workspaces, I want to type a few characters of a workspace
   name and land on it, so that navigation costs keystrokes proportional to how specific I
   am rather than to how far away the target is.
2. As a herdr user, I want to open the finder with a single prefixed keypress, so that
   jumping does not interrupt what I was thinking about.
3. As a herdr user running several coding agents, I want to search by agent name, so that
   I can reach "the agent called reviewer" without remembering which workspace it lives in.
4. As a herdr user, I want to search by agent kind (claude, codex, …), so that I can find
   the sessions of one tool among many.
5. As a herdr user, I want to search by a pane's working directory, so that I can find work
   by repository even when the workspace label says something else.
6. As a herdr user, I want to search by a pane's terminal title, so that I can find a pane I
   never named — the title already says `nvim src/handler.rs`.
7. As a herdr user, I want the finder to include plain shell panes, so that a scratch
   terminal I opened an hour ago is as reachable as an agent session.
8. As a herdr user, I do not want forty rows of identical `bash ~` shells, so that the list
   stays scannable; the default view should show one row per workspace and nothing else.
9. As a herdr user, I want a collapsed workspace row to still match on its child panes'
   directories and titles, so that collapsing never hides something from search.
10. As a herdr user, I want one key to cycle between collapsed, fully expanded, and
    agents-only views, so that I can widen or narrow the list without leaving the finder.
11. As a herdr user, I want the current view mode shown in the prompt, so that I always know
    which of the three lists I am looking at.
12. As a herdr user, I want rows ordered by workspace number, so that the finder's order
    matches the sidebar and my existing muscle memory.
13. As a herdr user, I want each agent's status shown as a colored glyph, so that I can see
    at a glance which sessions need me.
14. As a herdr user, I want `blocked` agents to stand out in red, so that an agent waiting on
    an approval is the first thing I notice.
15. As a herdr user, I want `done` to be visually distinct from `idle`, so that "finished
    work I have not looked at yet" is distinguishable from "sitting there doing nothing" —
    that distinction is usually the reason I am opening the finder.
16. As a herdr user, I want the currently focused location marked, so that I know where I
    am relative to where I am going.
17. As a herdr user working with git worktrees, I want worktree workspaces labeled with
    their repository name and checkout, so that four checkouts of the same repo are
    distinguishable.
18. As a herdr user, I want a glyph marking linked worktree checkouts, so that I can tell a
    worktree from the primary checkout without reading the path.
19. As a herdr user, I want to search worktree workspaces by both repository name and
    checkout name, so that either half of what I remember gets me there.
20. As a herdr user, I want a preview of the highlighted pane's recent output, so that I can
    distinguish two rows that look identical in the list.
21. As a herdr user, I want the preview to work for every row type, so that I never have to
    learn which rows have previews and which do not.
22. As a herdr user, I want a collapsed workspace row's preview to show what panes it
    contains, so that collapsing does not cost me information at the moment I need it.
23. As a herdr user, I want to toggle the preview off, so that I can trade context for a
    wider list.
24. As a herdr user, I want `Enter` to focus the exact pane I selected — not just its
    workspace — so that I arrive ready to type.
25. As a herdr user, I want the popup to disappear before focus moves, so that I never see a
    finder floating over a session it is no longer describing.
26. As a herdr user, I want `Esc` to close the finder and change nothing, so that opening it
    to look around is free.
27. As a herdr user, I want the finder to be fast with no perceptible lag while typing, so
    that it feels like a filter rather than a query.
28. As a herdr user, I want `Ctrl-r` to refresh the list, so that I can pick up a workspace
    that appeared while the finder was open.
29. As a herdr user, I want the list to hold still while I type, so that a status change
    elsewhere in the session never moves the row under my fingers mid-selection.
30. As a herdr user, I want `Ctrl-n` to create a new workspace without leaving the finder,
    so that "the thing I am looking for does not exist yet" is one keystroke from resolved.
31. As a herdr user, I want a new workspace to inherit the working directory of the row I had
    highlighted, so that it starts in the repo I was already thinking about.
32. As a herdr user, I want to name a new workspace at creation, or accept herdr's default
    label by submitting an empty name, so that naming is optional.
33. As a herdr user, I want to land in the workspace I just created, so that creating and
    switching are one action.
34. As a herdr user, I want `Ctrl-x` to close the selected thing, so that tidying up does not
    require navigating to each workspace first.
35. As a herdr user, I want `Ctrl-x` on a pane row to close that pane and on a collapsed
    workspace row to close that workspace, so that the key does what the row I am looking at
    implies.
36. As a herdr user, I want a confirmation before anything is closed, so that a mistyped key
    never destroys running work.
37. As a herdr user, I want closing my last remaining workspace to be refused, so that I
    cannot empty the session out from under myself.
38. As a herdr user, I want herdr's own "this would close a worktree group" warning surfaced
    as a second explicit confirmation, so that worktree teardown is never silent.
39. As a herdr user, I want the list to refresh after I create or close something, so that
    the finder reflects what I just did.
40. As a herdr user, I want the finder's colors to follow my terminal theme, so that it looks
    native under `vesper` or anything else I switch to.
41. As a herdr user, I want the finder to open as a bordered floating popup rather than
    rearranging my layout, so that using it never disturbs my panes.
42. As a herdr user, I want the popup sized as a percentage of the terminal, so that it looks
    right on any display.
43. As a herdr user, I want a clear message if `fzf` or `jq` is missing, so that a failed
    install is diagnosable in one read.
44. As a herdr user, I want a clear message when herdr refuses to open the popup because I
    am not in the normal workspace view, so that the plugin does not appear broken when it
    is being correctly refused.
45. As a herdr user, I want a message when my chosen target disappeared between selecting it
    and jumping, so that a silent no-op is never ambiguous.
46. As a herdr user, I want every failure recorded in the plugin log, so that I can debug
    with `herdr plugin log list` after the toast is gone.
47. As a herdr user, I want pressing the finder key twice to focus the finder that is already
    open rather than stacking a second one, so that an impatient double press is harmless.
48. As a herdr user, I want a finder left open and forgotten to eventually clean itself up,
    so that abandoned invocations do not leak processes or state files.
49. As a herdr user, I want to install the plugin from a local checkout with
    `herdr plugin link`, so that I can develop it and use it at once.
50. As a herdr user, I want the plugin to declare the herdr version it needs, so that it
    fails loudly rather than mysteriously on an older herdr.
51. As a herdr user, I want the trigger key documented but not forced, so that I can shadow
    the built-in `prefix+w` if I decide the plugin replaces it.
52. As a herdr user, I want a README describing installation, keys and configuration, so
    that the plugin is usable by someone who is not me.
53. As a contributor, I want tests that run against a throwaway herdr server, so that the
    suite never touches my live session state.
54. As a contributor, I want row construction testable without driving `fzf`, so that the
    logic that matters is covered by fast, non-interactive tests.

## Implementation Decisions

### Plugin shape

- Distributed as a herdr plugin with `herdr-plugin.toml` at the repository root. Plugin id
  `workspace-manager`; repository `herdr-workspace-manager`.
- `min_herdr_version = "0.8.0"` (required manifest field; matches the API surface used).
- Pure Bash. No `[[build]]` section. Runtime dependencies: `fzf`, `jq`, and the `herdr`
  CLI (always present, since the plugin only runs inside herdr).
- Manifest declares one action, `open` — the thing the user binds — and one pane
  entrypoint, `finder`, with `placement = "popup"`, `width = "80%"`, `height = "70%"`.

### Why geometry lives in the manifest

`herdr plugin pane open --placement` accepts only `overlay | split | tab | zoomed`;
`popup` is reachable only as a manifest-declared placement. Popup width and height are
therefore manifest properties and cannot be overridden per-invocation. This is documented
as an explicit limitation: changing the popup size means editing the linked manifest.

### Invocation flow

1. The user binds a key in `config.toml`:
   `[[keys.command]]` with `type = "plugin_action"` and the `workspace-manager:open`
   action. Documented default `prefix+f`, with a note that `prefix+w` can be shadowed to
   replace the built-in picker.
2. The action command runs as an ordinary spawned process **outside** the popup, with its
   stdout/stderr captured into herdr's plugin command log. It:
   - mints a correlation id;
   - if a `workspace-manager` plugin pane is already live, focuses it and exits;
   - otherwise opens the `finder` entrypoint, passing the per-invocation choice file path
     through `--env`;
   - waits for that pane to close using the API's single-event wait with a timeout;
   - reads the choice file and performs the focus sequence;
   - removes the choice file.
3. The finder entrypoint runs inside the popup: takes one session snapshot, builds rows,
   runs `fzf`, writes the chosen target to the choice file, and exits. Pane exit closes the
   popup.

The action process, not the popup, performs focus. This avoids asking herdr to change
focus underneath a modal popup (an untested and plausibly rejected operation), and keeps
failures visible in the plugin log. The popup never needs to close itself, so the plugin
never has to hand-roll a raw socket request for the `popup.close` method, which has no CLI
verb.

### Handoff protocol

- One choice file per invocation, named by correlation id, under the plugin's state
  directory as provided by herdr's plugin environment.
- Empty or missing file means the user aborted; the action exits without touching the
  session.
- Wait timeout of 600 seconds, after which the action cleans up the choice file and exits
  quietly.
- Concurrency is resolved by focusing the existing finder pane rather than opening a
  second popup.

### Data acquisition

- Exactly one `session.snapshot` request per refresh, yielding workspaces, tabs, panes,
  agents and layouts together. Rows are built from that single document with `jq`.
- No queries are issued while the user types or moves the selection; the preview is the
  only per-selection call.
- Refresh happens on open, on `Ctrl-r`, and after a successful create or close. No
  event subscription during the popup's lifetime — the popup lives for seconds, and
  live reordering under the user's fingers is a worse failure than staleness.

### Row model

Row fields, all included in the fuzzy haystack:

- workspace number
- workspace label — for linked worktree checkouts, rendered as repository name plus
  checkout name with a worktree glyph, using the workspace's worktree metadata
- tab label
- agent kind and agent name
- agent status
- working directory
- pane terminal title

Row types:

- **pane row** — one navigable pane, with or without an agent.
- **workspace row** — a whole workspace as a single row, used by the collapsed view. Every
  workspace collapses, whatever is inside it: the collapsed view answers "which workspace?"
  and nothing else, because panes and agents each have a view of their own. The row takes
  its status from the workspace's aggregate status, names its agent (or counts them when
  there are several), and keeps its child panes' directories, titles and agent names in the
  searchable haystack via hidden fields, displayed only in the preview.

View modes cycle with one key: collapsed (one row per workspace) → expanded (every pane) →
agents-only. The active mode is shown in the finder prompt.

Ordering is by workspace number, matching the sidebar. Agent status affects color only,
never position.

### Status presentation

Status maps to a glyph and an ANSI color: `blocked` red, `working` yellow, `done` green,
`idle` dim, `unknown` dim. `done` and `idle` get distinct glyphs because herdr
distinguishes "finished work not yet seen" from "idle", and the former is a navigation
trigger. The focused location is marked with a leading indicator. Colors are ANSI palette
entries, never fixed RGB, so the finder follows the active terminal theme — the same
choice `tmux-session-finder` makes.

### Preview

A single code path for all row types: read the target pane's recent output, ANSI stripped,
bounded line count, rendered in `fzf`'s preview window at the right, half width, toggleable.
Collapsed workspace rows prepend a short inventory of the workspace's panes above the
output. Agent-specific reads add nothing over pane reads for preview purposes and are not
used.

### Mutations

- **Create**: prompts for a name; creates a workspace whose working directory is inherited
  from the highlighted row; an empty name accepts herdr's default label; focus moves into
  the new workspace.
- **Close**: row-typed. A pane row closes that pane; a collapsed workspace row closes that
  workspace. Both are gated behind a `y/N` confirmation inside the popup. Closing the last
  remaining workspace is refused outright. herdr's `confirmation_required` response (which
  guards worktree groups) is surfaced as a second, explicit confirmation rather than
  auto-confirmed or swallowed.

### Key bindings inside the finder

`Enter` jump · `Ctrl-a` cycle view mode · `Ctrl-n` new workspace · `Ctrl-x` close ·
`Ctrl-r` refresh · preview toggle · `Esc` abort. `fzf` runs with multi-select disabled and
a `begin`-weighted tiebreak. `Ctrl-n`, `Ctrl-x` and `Ctrl-r` intentionally match
`tmux-session-finder`. `Ctrl-e` is deliberately left unbound in v1 so that when rename
arrives it does not first mean something else.

### Configuration

- Popup geometry: manifest only, documented as such.
- Optional configuration file in the plugin's herdr-provided config directory, covering
  preview on/off and preview size.
- Everything else — colors, glyphs, key bindings, sort order — is hardcoded in v1.

### Error handling

Missing `fzf`/`jq`, a refused popup open (herdr rejects popup panes outside the normal
workspace view, and while the UI is busy), a target that vanished between selection and
focus, and any other API error each produce a herdr notification with a one-line message,
plus a stderr line captured in the plugin command log. Silence is never an acceptable
outcome for these cases: the failure modes are all recoverable, and a silent no-op makes a
correctly-behaving plugin look broken.

## Testing Decisions

### What a good test looks like here

Tests exercise externally observable behavior: given a session containing certain
workspaces, tabs, panes and agents, the finder produces certain rows, and choosing a row
results in a certain focus state. Tests do not assert on internal function names, the shape
of intermediate `jq` filters, or the wire format of individual requests.

### Seams

The intended test seams, kept deliberately few:

1. **Row builder** — session snapshot JSON in, rendered rows out. A pure transformation
   invoked as a script with the snapshot on stdin, so tests supply fixture snapshots
   directly and assert on rows. This is the highest-value seam and covers view modes,
   collapsing, hidden haystack fields, worktree labeling, status glyphs and ordering
   without any running server.
2. **Live API seam** — a headless `herdr server` on a private socket. Tests drive real
   workspace/pane creation through the CLI, snapshot it, and assert that the focus routine
   lands the session on the intended workspace, tab and pane. This covers the parts that
   fixtures cannot honestly test: that the focus sequence works against a real server, and
   that create/close behave as expected.

`fzf` itself is never driven interactively. Where selection must be simulated, `fzf`'s
non-interactive filter mode is used against the row builder's output, which also gives
direct coverage of whether the haystack actually matches the queries the feature promises
(agent name, cwd, terminal title, worktree checkout).

### Critical test hygiene

A headless herdr server started without an explicit private socket restores the user's real
persisted session. Every test run must set both a private socket path and a private
configuration/state location, so the suite cannot read or overwrite live session state.
This was observed in practice while validating the API for this spec.

### Prior art

`tmux-session-finder`'s `tests/run.sh` is the model: a shell test runner that stands up an
isolated server of the multiplexer under test, exercises the plugin's scripts against it,
and never touches the developer's live sessions. The same runner shape and the same
isolation guarantee apply here.

## Out of Scope

Deferred to v2, deliberately and not by omission:

- **MRU ordering.** herdr exposes no last-focused timestamp, so recency ordering requires
  the plugin to keep its own state via a startup hook and an event subscription. This is
  the most likely thing to be missed in practice, but it is a background daemon and a
  separate concern from the finder.
- **Rename** from within the finder.
- **Worktree create/open** from within the finder.
- **`[[events]]` hooks** and **link handlers**, both available in herdr's plugin manifest
  and unused in v1.
- **Status-first sorting** — v1 conveys status through color only.
- **GitHub publication** and `herdr plugin install` documentation; v1 is installed as a
  linked local plugin.
- Configuration of colors, glyphs and in-finder key bindings.
- Any change to herdr's own built-in picker; this plugin sits alongside it.

## Further Notes

- herdr's plugin environment supplies the socket path, plugin root, config directory, state
  directory, entrypoint id and an invocation context describing the focused workspace, tab,
  pane, agent and worktree. The plugin does not need to discover any of this itself.
- The session snapshot is the single source of truth for the finder. Workspace records
  carry worktree metadata and a metadata token map; pane records carry working directory,
  foreground working directory and terminal title; agent records carry name, kind and
  status. Between them, every row field is available from one request.
- The `focus` sequence is written as workspace → tab → pane rather than assuming a pane
  focus implicitly pulls its ancestors. Whether the implicit behavior holds has not been
  verified, and the explicit sequence is correct either way.
- The plugin deliberately mirrors `tmux-session-finder` in structure, key vocabulary,
  snapshot-once performance model and theme-following colors, so that the two tools feel
  like the same tool against different multiplexers.
