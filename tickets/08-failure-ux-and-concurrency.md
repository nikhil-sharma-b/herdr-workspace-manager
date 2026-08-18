# 08 — Failure UX and concurrency

**What to build:** Every way this plugin can fail becomes legible in the two seconds the
user is looking at it. A missing dependency, a popup herdr refuses to open because the
user is not in the normal workspace view, a jump target that vanished between selection
and focus, and any other API error each produce a short notification, plus a line in
herdr's plugin command log for debugging after the notification is gone. Silence is never
the outcome: all of these are recoverable situations, and a silent no-op makes a
correctly-behaving plugin look broken.

Impatience is also handled. Pressing the key a second time while the finder is open
focuses the finder that already exists rather than stacking a second popup. An invocation
that is opened and forgotten cleans itself up rather than leaking a waiting process and a
stale state file.

**Blocked by:** 01 — Walking skeleton: key → popup → jump.

**Status:** done

- [x] Missing required tools produce a notification naming what to install, and the
      failure is recorded in the plugin log
- [x] A popup that herdr refuses to open because the user is not in the normal workspace
      view, or because the interface is busy, produces a notification explaining that,
      not a silent no-op
- [x] A focus target that no longer exists when the popup closes produces a notification
      and leaves the session untouched
- [x] Any other API error produces a notification with a one-line message
- [x] Every failure path also writes a diagnostic line captured by herdr's plugin command
      log
- [x] Invoking the action while a finder pane is already open focuses that pane and does
      not open a second popup
- [x] An invocation whose popup is never resolved times out, removes its choice file, and
      exits without touching the session
- [x] No failure path leaves an orphaned waiting process behind
- [x] Normal aborts, such as pressing Esc, produce no notification
- [x] Tests cover the missing-dependency path, the vanished-target path, and the
      double-invocation path

**Implementation note:** a second press detects the live invocation and declines to open a
second popup, but cannot *focus* the popup that already exists: `plugin.pane.open` returns
no pane id for popup placement, so there is no handle to pass to `plugin.pane.focus`. This
is documented in the README's limitations.

**Implementation note:** two orphan paths were found by running this against a real
session and fixed. `fzf` now runs in the background with the finder waiting on it, because
a signal trap cannot run while a foreground child holds the shell — without that, a killed
popup never resolved its handoff and the action waited out its whole timeout. And the
action now closes a finder that outlived its invocation, using the pid the finder records
in its run directory: herdr permits one popup at a time, so an abandoned finder would
otherwise block every later press.
