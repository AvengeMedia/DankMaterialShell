# Attached panel example

A normal widget plugin that also sets `attachedContent`. Enable it in Settings → Plugins
and add it to a bar, a dock, or both.

- On a bar, a click opens the regular popout.
- On a dock, what a click does is the dock's choice. With Settings → Dock → Apps & widgets
  → Open widgets set to Inline, the dock grows and shows the attached panel next to the
  apps. With Popout (the default) it opens the same popout the bar would.

Escape or Close dismisses the panel and hands focus back to the widget. Opening another
attached widget replaces the panel. No background process, no timer.

See [the surface widget contract](../SURFACE_WIDGETS.md).
