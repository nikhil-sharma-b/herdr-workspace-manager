# 09 — Configuration and documentation

**What to build:** The plugin becomes installable and adjustable by someone who is not its
author. A README explains installing from a local checkout, binding a key to the plugin's
action, every key available inside the finder, and how to configure it.

A small optional configuration file, read from the directory herdr provides for plugin
configuration, covers preview on/off and preview size. Everything else stays hardcoded in
this version.

One limitation must be documented rather than papered over: the popup's width and height
are declared in the plugin manifest, because popup placement is only available as a
manifest-declared placement. Changing the popup size therefore means editing the manifest
of the linked plugin, not the configuration file. A configuration file that silently
cannot change geometry would be a trap.

**Blocked by:** 05 — Preview window.

**Status:** done

- [x] An optional configuration file in herdr's plugin configuration directory controls
      whether the preview is shown by default and how much of the popup it occupies
- [x] Absent, empty or malformed configuration falls back to defaults without breaking the
      finder
- [x] The README documents installing from a local checkout
- [x] The README documents the key binding, including the binding type used and the
      suggested default key, and notes that the built-in workspace picker's key can be
      shadowed if the user prefers
- [x] The README lists every key available inside the finder and what it does
- [x] The README documents the required dependencies and the minimum herdr version
- [x] The README states explicitly that popup width and height are manifest-declared and
      cannot be changed from the configuration file
- [x] The README documents how to run the test suite and that it never touches live
      session state
- [x] Following the README from a clean checkout produces a working finder

**Implementation note:** the README also documents a dependency the spec did not
anticipate — `socat` (or `python3`) — because `herdr pane focus` is direction-only and
focusing a pane by id needs the socket API directly.

**Revised after use:** the preview now defaults to *off*, and `Ctrl-p` persists its state
in the plugin's state directory so the choice survives closing the finder. Originally the
toggle was per-popup only and the preview defaulted on, which meant hiding it never stuck —
the next press brought it back. The configuration file still sets the starting value; a
recorded toggle outranks it as the more recent instruction.
