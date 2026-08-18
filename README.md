# herdr-workspace-manager

A [herdr](https://herdr.dev) plugin: a floating fuzzy finder over every workspace, tab,
pane and agent in the session. Type a few characters of a workspace name, an agent name, a
repository path or whatever a pane is currently running, press `Enter`, and the session
lands there.

It is the herdr counterpart of `tmux-session-finder`: one snapshot when it opens, no
queries while you type, ANSI colours that follow your terminal theme, and the same
`Ctrl-n` / `Ctrl-x` / `Ctrl-r` key vocabulary.

## Requirements

- herdr **0.8.0** or newer (declared as `min_herdr_version` in the manifest)
- `fzf`
- `jq`
- `socat`, or `python3` as a fallback

`socat`/`python3` are needed for exactly one call: focusing a specific pane by id.
`herdr pane focus` only moves to a *neighbouring* pane by direction, while the socket API
focuses a pane by id — so the plugin speaks to the socket directly for that one request.
Everything else goes through the `herdr` CLI.

The finder refuses to start with a one-line message naming whatever is missing.

## Install from a local checkout

```sh
git clone https://github.com/nikhil-sharma-b/herdr-workspace-manager ~/repos/herdr-workspace-manager
herdr plugin link ~/repos/herdr-workspace-manager
```

`herdr plugin list` should now show `workspace-manager` with an `open` action and a
`finder` pane entrypoint. To develop and use it at once, keep working in the linked
checkout — changes to the scripts take effect on the next invocation. Changes to
`herdr-plugin.toml` need `herdr plugin link` again.

Remove it with `herdr plugin unlink workspace-manager`.

## Bind a key

Add to `~/.config/herdr/config.toml`:

```toml
[[keys.command]]
key = "prefix+f"
type = "plugin_action"
command = "open"
```

Then `herdr server reload-config`.

The action is named by `command`, and the value is the bare action id — `"open"`, not
`"workspace-manager:open"`. There is no separate plugin field on a key binding; herdr
resolves the action id across installed plugins, and only complains if two plugins declare
the same one.

`prefix+f` is only a suggestion. If you decide this finder replaces herdr's built-in
workspace picker, bind it to `prefix+w` instead — shadowing the built-in binding is
supported and nothing in the plugin depends on which key you choose.

## Keys inside the finder

| Key | What it does |
| --- | --- |
| type | fuzzy-filter the list; every field is searchable, displayed or not |
| `Enter` | close the popup and focus the selected workspace, tab and pane |
| `Esc` | close the popup and change nothing |
| `Ctrl-a` | cycle the view: workspaces → panes → agents → workspaces |
| `Ctrl-n` | create a workspace, then land in it |
| `Ctrl-x` | close the pane or workspace the highlighted row stands for |
| `Ctrl-r` | re-read the session and redraw |
| `Ctrl-p` | toggle the preview |

The prompt always names the active view, so which of the three lists you are looking at is
never ambiguous.

`Ctrl-e` is deliberately unbound, so that when rename arrives it does not first mean
something else.

### Views

- **workspaces** (default) — one row per workspace, whatever is inside it, so forty
  identical `bash ~` shells never drown the list. The row shows the workspace's status, its
  agent by name (or a count when there are several) and its tab/pane totals. It still
  matches when you type the working directory, terminal title or agent name of anything
  inside it, and selecting it lands on that workspace's active pane.
- **panes** — one row per pane, nothing collapsed.
- **agents** — only panes with a detected agent.

### Status

Each row carries a status glyph, coloured from the terminal's ANSI palette:

| Glyph | Status | Colour |
| --- | --- | --- |
| `●` | blocked | red |
| `◐` | working | yellow |
| `✔` | done | green |
| `·` | idle | dim |
| `○` | unknown | dim |

`done` — finished work you have not looked at yet — is a different glyph from `idle`, not
just a different colour, because that distinction is usually the reason the finder is open.
The row you are currently on is marked with a leading `◆`.

Linked worktree checkouts render as `repo ⑂ checkout` and match on either half, so four
checkouts of one repository stay distinguishable.

### Creating and closing

`Ctrl-n` prompts for a name and creates a workspace in the working directory of the row you
had highlighted. An empty name accepts herdr's default label; `Ctrl-D` cancels. The new
workspace becomes the focused one.

`Ctrl-x` closes what the highlighted row represents — a pane row closes that pane, a
collapsed workspace row closes that workspace — always behind a `y/N` confirmation that
defaults to no. Closing the last remaining workspace, or the last pane of the last
workspace, is refused outright. Closing the primary checkout of a repository that has open
worktree workspaces asks a second, explicit time and names the worktrees that will go with
it, because herdr tears that group down without asking.

## Configuration

Optional, at `$(herdr plugin config-dir workspace-manager)/config.toml`:

```toml
preview = true       # show the preview when the finder opens
preview_size = 50    # percent of the popup width the preview occupies (10–90)
```

An absent, empty or malformed file falls back to these defaults rather than breaking the
finder.

**The popup's width and height are not configurable from this file.** They live in
`herdr-plugin.toml`:

```toml
[[panes]]
id = "finder"
placement = "popup"
width = "80%"
height = "70%"
```

This is a herdr constraint, not an oversight: `herdr plugin pane open --placement` accepts
only `overlay | split | tab | zoomed`, so `popup` is reachable only as a manifest-declared
placement, and width and height are only accepted alongside it. Changing the popup's size
means editing the manifest of the linked checkout and running `herdr plugin link` again.

Colours, glyphs, sort order and the in-finder key bindings are hardcoded in this version.

## How it works

Pressing the key invokes the `open` action, which runs **outside** the popup as an ordinary
spawned process with its output captured into herdr's plugin command log. It opens the
`finder` pane entrypoint as a popup, passing a per-invocation choice file through the
environment, waits for the popup to resolve, reads the choice and then focuses
workspace → tab → pane.

The finder itself runs inside the popup: one `session.snapshot` per refresh, rows built
from that single document, `fzf` over those rows, the chosen target written to the choice
file, exit. Exiting is what closes the popup.

Focus is performed by the action rather than by the popup deliberately: herdr is never
asked to move focus underneath a modal popup, the popup never needs to close itself, and
every failure stays visible in `herdr plugin log list`.

Refreshes happen on open, on `Ctrl-r`, and after a create or close. Typing, moving the
selection and switching views never query the session — the list holds still while you
type, so a status change elsewhere cannot move the row under your fingers.

### Known limitations

- **Geometry is manifest-only**, as described above.
- **A second press while the finder is open is a no-op, not a re-focus.** herdr's
  `plugin.pane.open` returns no pane id for popup placement, so the plugin has no handle to
  focus the popup that already exists. It detects the live invocation and declines to stack
  a second popup, which is the part that matters. herdr allows one popup at a time and
  refuses the second itself (`popup already open`), which the action reports rather than
  failing generically.
- **An abandoned finder is closed by its own action.** Because only one popup can be open
  at a time, a finder left open past the 600s timeout would block every later press. The
  finder records its pid in its run directory, and the action closes it on the way out; the
  finder resolves its handoff when signalled, so nothing is left half-written.
- **`confirmation_required` from herdr cannot be confirmed through.** herdr's close methods
  take no force flag, so if herdr itself asks for confirmation the finder shows the reason
  and stops rather than pretending. The worktree-group case is handled by the plugin's own
  second confirmation, before the call.

## Tests

```sh
./tests/run.sh
```

Fixture cases run the row builder — session snapshot in, rendered rows out — with no server
and no terminal. Live cases run against a herdr server the suite starts itself, on a
private socket with a private `HOME` and XDG directories.

**The suite never touches your live session.** This matters more than it sounds: a headless
herdr server started without an explicit private socket restores the real persisted session
from `~/.config/herdr/session.json`, and can rewrite it. Every server the harness starts
gets both a private socket path and a private configuration and state tree.

`fzf` is never driven interactively; where selection has to be simulated the suite uses
`fzf --filter`, which also proves the haystack really matches the queries the finder
promises — agent name, working directory, terminal title, worktree checkout.
