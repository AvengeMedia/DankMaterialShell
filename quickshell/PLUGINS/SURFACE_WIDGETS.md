# Widgets on bars and docks

Widget plugins use the same `PluginComponent`, manifest, discovery, horizontal and
vertical pill components, settings, and popout APIs on both surfaces. A dock is a
named configuration with a single ordered list. Each list entry has a persistent
instance ID distinct from its widget type or plugin variant ID. The same widget can
appear on multiple surfaces or multiple times in a dock.

`PluginComponent.surfaceContext` describes the invoking surface:

| Property | Meaning |
| --- | --- |
| `kind`, `id` | `bar` or `dock`, and the configuration ID |
| `screen`, `axis`, `isVertical` | The actual host display and edge orientation |
| `thickness`, `widgetThickness`, `availableSize` | Logical dimensions and available primary-axis space |
| `revealed`, `live` | Visibility and whether visual updates are useful; `live` also excludes powered-off monitors |
| `editMode` | Widget editing; ordinary app dragging still reorders pins |

`widgetInstanceId` identifies this occurrence. `surfaceLive` combines the context's
live state with the plugin's visibility condition. Bind optional visual timers and
animations to it; share system data through services instead of adding per-instance
polling. The existing visibility-command timer pauses with the host. Hidden and
removed widget loaders release their contents. Plugin settings remain plugin scoped;
the context does not change their existing persistence contract.

Define both `horizontalBarPill` and `verticalBarPill`. Components must fit the supplied
cross-axis thickness and expose a useful implicit primary-axis size. Avoid assuming
that the parent is a DankBar or that the widget is the only instance. Actions and
popouts use the invoking instance's display; dock Popout mode resolves the matching bar location. The existing public
`BarWidgetService.getWidget(type, screen)` lookup selects deterministically by owner
ID (bars before docks), then screen name. Its optional third argument selects an
exact registration owner. Registration and unregistration use the same instance
owner and item reference, so destroying one copy cannot remove another.

## Optional attached content

Normal actions continue to open their regular popouts. Provide an
`attachedContent: Component` to make a widget expandable inside a dock.

Whether it is used is the dock's decision, not the plugin's: each dock configuration
has an "Open widgets" setting of `popout` (default) or `inline`, exposed as
`surfaceContext.inlineExpansion`. Under `inline`, any widget with `attachedContent`
expands the dock via `surfaceContext.requestExpansion(widget)`. Under `popout`,
widgets use their normal bar location on the same display, except those with no popout at all, which have no
other surface and still expand inline. A bar always uses `popoutContent` as before,
and explicit `pillClickAction` handlers keep control of their action.

The panel spans the dock's length and grows 320 px (at most half the screen) away from the edge; the plugin does not choose its size, so lay the content out for a narrow dock too. Only one attached panel is open per dock. The host owns and destroys its Loader,
keeps applications visible, holds auto-hide during interaction, and preserves the
normal exclusive-zone reservation while the inner surface grows. Escape and
`surfaceContext.dismissExpansion()` close it and restore focus. Removing, disabling,
or unloading its owner closes the panel. `attachedActive` reports ownership. Use
Theme tokens and respect `surfaceLive`; do not start a new service for the panel.

[AttachedPanelExample](AttachedPanelExample/) demonstrates both orientations,
regular bar popouts, and the attached dock contract.

### Shared activity presentation

`MediaActivitySource` and `MediaActivityFace` live in `Modules/SurfaceWidgets`.
The face accepts a media model, orientation, density, artwork size, and optional
clock visibility; it exposes implicit dimensions and clock actions/hover state.
It has no Island controller dependency. Island adapters translate those signals
into Island navigation and sizing. `MediaActivity` adapts the same face to the
normal bar/dock pill and media-popout route.

First-party pills receive `surfaceLive` from the shared widget host. Use it to
suspend visual work while the surface is hidden without unloading widget state.
Notification and system-level activity ownership remains with the Island/OSD;
these are not instantiated as additional dock controllers.
