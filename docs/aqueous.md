# Aqueous integration

DMS uses Aqueous runtime IPC v1 through the existing QML `DankSocket` and
`SplitParser` stack, as used by the other compositor services. Build a compositor
that exports `AQUEOUS_SOCKET` and verify its `hello`; an installed executable's
version does not establish support. No released minimum version is established.

Earlier desktop integration was tested against Aqueous
`2d8b07fb1ff2354ea0c3acddd5cc84ceb823d6eb`. The runtime socket checks below use the
new IPC build, with Quickshell `2d3b3e9c70ef380dff751b61d334dc88df016c29` and its
existing `parentWindow` API. No native Quickshell module or shared QML submodule
change is needed for this migration.

## Implemented paths

| Work | Implementation |
| --- | --- |
| P0–P2 | Socket-owner detection, capability discovery, orderly logout, bounded atomic stream reducer, reconnect, stable window/workspace identities, selected-seat output routing, taskbars/docks, focused app and workspace controls. |
| P3 | Effective keyboard group/layout state and runtime switching with explicit seat/group identities. |
| P4 | Active-window and selected-output screenshots. Window capture crops the composed output's outer bounds, including compositor borders and occluders. |
| P5 | Generic output-power discovery and DPMS dispatch, preserving specialized compositor paths. |
| P6 | Actual asynchronous display results, request timeouts, cancellation and suppression of late callbacks. |
| P7 | Helper-backed keybinding inventory, unbound built-ins, multiple bindings, custom commands, edits/removal and generation conflicts. |
| P8 | Runtime test/apply and Keep/Revert; generation-checked persistence of supported monitor mode, position and transform changes. Unsupported helper operations fail explicitly. |
| P9 | Manual cursor and typography Apply, adapter reports, partial-success retry and generation checking. |
| P10 | Native compositor overview control/state and existing connected-frame reservations. No extra margin protocol or persistent gap writes. |

The native DMS appearance provider performs no background synchronization. The
existing Aqueous Settings plugin retains ownership of any automatic synchronization
the user enabled there. Opening either settings frontend does not save Aqueous
configuration. Both frontends must use the helper's observed generation when saving.
The independent portal plugin and its enablement preference are unchanged.

## Runtime and configuration

Start DMS as an Aqueous session child, inheriting `AQUEOUS_SOCKET` and
`XDG_RUNTIME_DIR`. The endpoint is an absolute path under
`$XDG_RUNTIME_DIR/aqueous/<instance>/ipc.sock`. DMS does not scan sessions or use
subprocess discovery. A new compositor instance needs DMS relaunched with its new
environment. Keep `aqueous-config` and its matching `aqueousctl` on PATH for the
retained configuration paths.

`AqueousService.qml` owns two persistent QML connections: one for hello/commands,
one for hello/subscription/acks. `AqueousConnection.qml` separates wire validation,
request correlation and deadlines from the service's atomic entity reducer and
existing UI facades. Both handshakes must agree on session, schema and capabilities;
readiness requires a validated initial snapshot. Events are acknowledged only after
installation. A broken stream invalidates the model, discards its parser and
baseline, and reconnects through `DankSocket`'s existing backoff with jitter.
There is no heartbeat, snapshot polling, watch process or runtime core manager.

Commands use JSON action/field objects and runtime output IDs directly. One request
is outstanding, with at most 32 waiting commands. The service revalidates the
captured session, seat, capability, lock and target before dispatch. Waiting
commands expire after five seconds when dequeued. Replies complete callbacks;
`applied` confirms commitment without waiting for the other connection's sequence,
and close/exit use `accepted`. A sent command without a valid acknowledgement has
an uncertain outcome and is never replayed. Unsent commands fail separately.
Handshake and request deadlines are five seconds; the initial subscription has an
eight-second deadline. Established subscriptions have no idle deadline.

The QML client checks complete frame sizes (4 MiB + 64 KiB), request sizes
(64 KiB), nesting, envelopes and advertised limits. Its retained entity model is
limited to 2 MiB. `SplitParser` preserves fragmented UTF-8 while assembling lines,
but does **not** expose a byte limit before LF, strict raw UTF-8 validation or peer
credentials. This QML implementation therefore relies on the compositor's bounded
output and private socket directory for those boundaries; it does not claim the
native framing/peer-verification guarantees in the original handoff. There is no
native transport dependency or subprocess fallback.

Standalone screenshots use the Linux-only `core/internal/aqueous_ipc.go`.
A short-lived Go Unix connection performs hello and snapshot, then closes. It enforces bounded framing
before LF, strict UTF-8, private directory/socket modes, peer UID and context
cancellation. Snapshot state enters the existing screenshot parser; composed pixel
capture, outer geometry, clipping and transforms are unchanged.

Settings and keybind editing remain a separate delivery. `AqueousConfigService`
still runs `aqueous-config`; `KeybindsService` still calls `dms keybinds`, whose Go
provider runs that helper. The helper itself currently invokes `aqueousctl outputs`
and `aqueousctl cursor`. These calls are outside the migrated runtime paths and
were observed by the integration launch counter. `AqueousService.runJson` remains
for these consumers. The separately shipped Aqueous settings plugin also remains
owned by Aqueous. A configuration socket contract is required before migrating
these operations.

All persistent writes go through `aqueous-config validate/apply --shell dms
--request -`, with JSON on stdin and `expected_generation`. The backup directory
passed to the helper is `$XDG_CONFIG_HOME/DankMaterialShell/aqueous-backups`;
the helper decides when backups are required. Background blur uses the Wayland
protocol and does not invoke the helper or write compositor configuration.
Display previews retain the previous live configuration and refuse to revert over
external changes or output recreation. A failed/uncertain preview is reconciled
against live state before offering Keep/Revert. A conflict retains the draft until
the user explicitly discards it and reloads.

### Background blur

DMS uses its standard `ext-background-effect-v1` path on Aqueous. Native support
was added in Aqueous `c6e5e566f892db1d7b2944f31404d037884fb0c6`; use a Vulkan
effects build and a Quickshell version providing `BackgroundEffect.blurRegion`.
Older Aqueous versions and builds without effects report blur as unavailable.

Enable global blur in Aqueous's `wm.toml` first, with positive radius and passes:

```toml
[blur]
enabled = true
radius = 8
passes = 2
```

Then enable Background Blur in DMS and set surface opacity below 100%. The
separate frame blur preference still controls frame regions. DMS supplies exact
regions, including rounded corners and clipping, through Quickshell. Requests
are per surface; popups need their own regions. No DMS namespace rule is required.
User-authored deny rules and Aqueous's global blur setting remain authoritative.

`dms blur check` detects the protocol global, not the runtime compositor blur
setting. It can report `supported` while global blur is disabled. DMS does not
change that setting, create layer rules, or run a configuration helper when blur
is toggled or the shell starts. Existing DMS blur preferences are preserved.

Run Aqueous's protocol and pixel regression suite against this checkout:

```sh
cd /path/to/Aqueous/compositor
LD_LIBRARY_PATH="$PWD/.deps/wlroots-render-hook/lib" \
  DMS_SOURCE=/path/to/DankMaterialShell \
  python3 scripts/test-background-effect.py
```

Use the updated DMS fixture that reads `BlurService.enabled`. The suite needs
matching Aqueous binaries, `qs`, `dms`, a C compiler, Wayland development files,
`wayland-scanner`, `grim`, and Python/Pillow. It runs on private outputs with
isolated configuration and checks protocol discovery, rounded/intersected regions,
toggles, hide/remap, and configuration preservation. The compositor checks also
cover popup/subsurface masks, policy reload, fractional output transforms, and
cached/uncached rendering. A separate `-Dvulkan-effects=false` build can be checked
with `AQUEOUS_TEST_NO_EFFECTS=1` and `AQUEOUS_COMPOSITOR_BIN=/path/to/aqueous`.
These headless checks do not establish physical mixed-scale or HDR rendering.

### Limitations in the pinned helper

`plugin/helper/src/main.zig::applyMonitorChanges` accepts monitor ID/name, position,
transform and mode. It does not apply scale, enablement or adaptive-sync fields.
`writeConfiguredMonitors` also requires a name and omits EDID-only entries.
DMS rejects unsupported persistence, EDID edits and ambiguous wildcard monitor
configuration instead of sending fields the helper would silently ignore.
Offline entries and unrelated fields remain owned by the helper.

Completing those P8 cases requires an Aqueous helper change, tests demonstrating
preservation of EDID/offline entries, and capability discovery for the expanded
request. Native DMS can then use that verified contract. Runtime scale/rotation
preview and capture work independently of this persistence limitation.

DMS typography represents family, weight and scale. Exact face/slant/width and
separately scaled bars may differ. Toolkit synchronization can partially fail after
the canonical save; inspect the adapter report and use explicit Retry.

### Keybind conflict recovery

Aqueous uses the same inline KeybindItem rows, new-binding form, confirmation
dialog and service save/remove/reset entry points as Hyprland and Niri. The tab
retains one Aqueous draft independently of the binding list, including its original
chord/action, compositor session and observed inventory. Draft state and review
controls live in KeybindsTab; KeybindsService handles the provider's snapshot,
generation and reconciliation checks.

Save, Remove and Reset read fresh bindings before dispatch. If only unrelated
configuration changed (for example, user layer rules), the operation uses the new
generation. Actual keybinding changes open a review state without writing.

Reload retains the proposal and displays the previous/current bindings and
destination chord. Accept reviewed changes adopts that baseline; Save still
performs a fresh check. Removal requires a new confirmation after review.
Deleted targets and duplicate/occupied chords must be resolved explicitly, or
the draft can be discarded. Session/provider changes invalidate pending work
while retaining the draft text. Filtering, collapsing the row and hiding/reopening
the tab do not reset it. Cancelling removal leaves the original edit intact.

Configuration changes between preparation and helper validation/apply still
produce a conflict. Failed and uncertain mutations are never automatically
replayed. Successful saves clear the draft even if the subsequent list refresh
fails, and failed operations cannot emit a later success event merely because
the list was refreshed. Refreshes run on session readiness, tab visibility,
explicit actions and mutation completion; there is no idle polling.

The UI and CLI must be updated together. Aqueous mutation commands support
`--json` to return `success`, `code` and a failure `message` or successful
`generation`. Failure exit codes remain nonzero. `external_change` identifies a
generation conflict; `uncertain` means helper application lacked a reliable
acknowledgement. CLI callers must still supply their observed
`--expected-generation`; only the UI has the retained baseline needed to compare
inventories before updating that generation.

Focused verification:

```sh
node quickshell/tests/aqueous-keybinds.test.mjs
python3 scripts/test-aqueous-keybinds.py --bin-dir /path/to/test/binaries
```

The integration test requires a Pixman-compatible Aqueous build, `aqueousctl`,
`aqueous-config`, Quickshell and the matching DMS binary. It creates a private
headless display and temporary configuration, then exercises the real Keybinds
tab, draft editing, blur-only changes, review/save/discard, removal reconfirmation,
structured CLI failures and idle behavior. It never connects to the user's display.

## Diagnostics

Run these inside the session being diagnosed:

```sh
aqueousctl shell capabilities --json
aqueousctl shell snapshot --json
aqueousctl shell watch --json
aqueous-config version
aqueous-config snapshot --shell dms
dms ipc call aqueous status
```

The watch command remains running until interrupted. Redact window titles and
configuration paths before sharing output. Missing socket/protocol/helper support is
reported as unavailable; a similarly numbered executable is not proof that the
running compositor has the required capabilities.

Multiple seats require a choice. For shell widgets use
`dms ipc call aqueous selectSeat SEAT`; this selection lasts for the shell session.
For screenshots use `dms screenshot window --seat SEAT` or
`dms screenshot full --seat SEAT`. Layer focus and no eligible window produce
active-window capture errors. Selected-output routing still works on empty
workspaces and during layer focus.

WorkspaceSwitcher uses direct Aqueous branches alongside its existing compositor
branches. AqueousService supplies authoritative window/workspace membership and
session identities; the existing ext-workspace path keeps native handles. No
shared workspace adapter or new provider interface is required. Aqueous icons
reuse the widget's existing grouping, cached icon list, sizing and hit-test path,
carrying the captured session with the window ID.

Set `DMS_FORCE_EXTWS=1` in the shell's launch environment to select ext-workspace
even when the Aqueous adapter is healthy. If the protocol is unavailable, the
forced workspace path is unavailable. Without the override, a disconnected
Aqueous adapter falls back to ext-workspace when available and returns to its
richer model after reconnection. The override changes workspace selection only;
other Aqueous consumers and native overview remain available. Ext activation uses
the protocol's native method and does not expose explicit-seat selection.

Workspace settings expose app icons, follow-monitor-focus, occupied-only filtering,
reverse scrolling and workspace state colors. The app-icon and occupied-only
switches are disabled while the Aqueous model is unavailable or `DMS_FORCE_EXTWS=1`,
because the generic workspace path has no authoritative window membership.
Saved preferences are retained for when the Aqueous model is used again.

The existing workspace rename dialog supports Aqueous:

```sh
dms ipc call workspace-rename open
dms ipc call workspace-rename toggle
dms ipc call workspace-rename close
```

Opening captures the selected seat's active workspace ID and compositor session.
Changing focus while the dialog is open does not redirect the rename. The dialog
closes after an `applied` result and retains the draft on failure. Missing state,
ambiguous seat selection, lock or observation-only policy prevents opening it.
Rename changes runtime state; it does not write persistent configuration.

Native overview controls are available through workspace right-click and:

```sh
dms ipc call aqueous overview show DP-1
dms ipc call aqueous overview hide DP-1
dms ipc call aqueous overview toggle DP-1
```

`OVERVIEW_REQUESTED` means dispatch, not committed success; `aqueous status`
reports the authoritative output/selection and command failures produce a toast.
The output argument is a connector label; entity identity remains the runtime ID.

There are no Aqueous methods on the core socket. UI consumers call the singleton's
typed `command` method; output runtime IDs are sent directly to the compositor.
Settings use `AqueousConfigService` and direct stdin helper requests. See the
[complete contract and schema](aqueous-integration-plan.md) for protocol semantics.

## Verification

The following historical checks passed against the pre-IPC pinned build on 2026-09-05
(the watcher-specific checks describe the earlier transport):

- Aqueous `zig build test`: 393 tests.
- Aqueous native and XWayland `scripts/test-shell-integration.py`: state/actions,
  keyboard, inhibition, flow control, four-edge reservations and cleanup, lock,
  overview and orderly exit.
- Real helper DMS-mode integration suite: validation, persistence, stale generation,
  toolkit retry and monitor requests.
- DMS Go suite and focused race tests for the JSON process utility, keybind provider and screenshots.
- Embedded and distro DMS builds, dankinstall, FreeBSD cross-builds, QML entrypoint
  lint, `go mod tidy`, generated settings search index and translation-term checks.
- Production QML reducer/command/helper tests: atomicity, reference migration,
  Unicode, string sequences above 2^53, full replacement, stale IDs, capabilities,
  command results and generation preservation.
- An offscreen Quickshell process harness loads the production services with fake
  CLI fixtures: split/coalesced writes, Unicode, malformed/oversize records,
  continuity mismatch, EOF, retry backoff, uncertain command timeout, idle behavior
  and child cleanup. This does not test a parser byte bound before a delimiter.
- JavaScript tests executing production display methods: delayed success/failure,
  supersession, timeout, late callback and disconnect cleanup; display identity,
  clipping-related configuration values, conflicts and helper capability limits.
- Real DMS daemon and Quickshell on two private Aqueous headless outputs, both
  standalone bars and connected frame: duplicate window titles/app IDs, keyboard
  switching, overview, active-window crops, helper validation/save/conflicts,
  keybind writes, one QML-owned watcher, reconnect after killing the watcher,
  orderly logout and process cleanup.
- Workspace tests exercise the established compositor selection, the forced-ext
  override, Aqueous padding/grouping/icon counts, native handle identity and
  captured sessions. The runtime harness exercises the actual icon hit test,
  duplicate-name renames, output following and fallback/reconnect. Settings/dialog
  tests cover control visibility and search conditions, forced-ext membership
  controls, captured rename targets, retained drafts, lock/stale-target rejection
  and late callbacks after reopening. Real UI runs exercise the settings controls
  and rename IPC/dialog, including focus changes and correction after failure.

Specialized Niri/Hyprland/Mango/I3-family selection was checked with synthetic inputs;
new live sessions for those compositors were not available for this correction.

The UI runs included the ungrouped taskbar, dock and keyboard widget.
The XWayland DMS run also captured a synthetic XWayland window (404×304), with
rotated/fractional native capture at 350×1145 and positive output origins.

Earlier standalone-bar runs produced 632×660 and 350×1205 window crops. The connected
frame run produced 616×648 and 330×1190 crops; the latter used scale 1.25,
90° rotation and output origin (-3000, -100). These are dimensions from those
synthetic fixtures, not universal expected window sizes.

Reproduce the focused desktop checks with a Pixman-compatible diagnostic build:

```sh
node quickshell/tests/workspace-view.test.mjs
node quickshell/tests/workspace-settings.test.mjs
node quickshell/tests/aqueous-service.test.mjs
node quickshell/tests/aqueous-ipc.test.mjs
python3 scripts/test-aqueous-service.py
node quickshell/tests/display-apply.test.mjs
node quickshell/tests/aqueous-displays.test.mjs
LD_LIBRARY_PATH=/path/to/patched-wlroots/lib \
  python3 scripts/test-aqueous-integration.py \
  --aqueous-source /path/to/Aqueous --bin-dir /path/to/matching/binaries
# Add --force-ext to verify the workspace widget through ext-workspace.
# Add --frame to exercise connected frame reservations.
# Add --xwayland for the XWayland capture check (positive output origins).
```

The binary directory must contain `aqueous`, `aqueousctl`, `aqueous-config` and
the DMS build under test. The harness compiles Aqueous's existing synthetic client
from the supplied source; it never connects to the user's display. It retains
logs, PNGs and helper snapshots in the printed temporary directory.
`qmlformat` 6.11.2 exits unsuccessfully without diagnostics for both the unchanged
baseline and modified `WorkspaceSwitcher.qml`; the other changed QML files parse,
and entrypoint lint and the real widget runs pass.

Physical DPMS off/wake, hotplug/resume, physical mixed-scale rendering, decorations
across real applications, direct/nested/UWSM logout combinations and full lock UI
integration still need desktop verification. Browser/recorder portal streaming is
a separate release gate. Headless checks do not establish those results.
DankLinux-Docs support tables, packaging and plugin registry publication remain
work for their owning repositories after release dependencies are established.

Keep the generic DPMS/result and UWSM logout fixes independently reviewable.
Popup compatibility changes are outside this integration and have been removed.

## Runtime IPC verification (2026-09-06)

The QML reducer, protocol, workspace, keybind and display JavaScript tests pass.
The offscreen socket harness checks hello, mismatched sessions, unsupported schema,
fragmented Unicode, coalesced response/events, ack ordering, malformed/oversized
complete frames, mid-frame disconnects, broken deltas, command queue limits, before/after-send timeouts,
accepted logout, unavailable startup and same-endpoint recovery. Its private
`aqueousctl` interceptor records zero launches. It tests the production QML files,
without connecting to the user's Wayland display or DMS sockets.

The two-second idle sample after fault/reconnect tests recorded zero CPU ticks,
zero socket bytes and no child processes. RSS remained 104524 KiB and voluntary
context-switch count did not change in the final offscreen sample. These numbers describe
the offscreen harness process, including Qt and prior oversized-frame allocations;
they are not whole-desktop resource measurements. Each run retains `/proc` samples,
traffic counters and QML logs in its printed temporary evidence directory.

Go socket and screenshot tests pass with the race detector
(`cd core && go test -race ./internal ./internal/screenshot`). They share the QML
hello fixture and cover bounded fake Unix servers, fragmented/coalesced frames,
malformed/truncated/oversized input, exact string sequences, stale-session errors,
cancellation and snapshot parsing.

The full DMS integration passed on two private headless outputs using:

```sh
# Build the modified DMS binary; the directory also needs the matching
# freshly built aqueous, aqueousctl and aqueous-config binaries.
cd core
go build -o /tmp/dms-aqueous-ipc-bin/dms ./cmd/dms
cd ..
LD_LIBRARY_PATH=/path/to/Aqueous/compositor/.deps/wlroots-render-hook/lib \
  python3 scripts/test-aqueous-integration.py \
  --aqueous-source /path/to/Aqueous --bin-dir /tmp/dms-aqueous-ipc-bin
```

The verified run used `/tmp/aqueous-ipc-build/bin/aqueous` and `aqueousctl`, with
`aqueous-config` from `/home/zoey/RiderProjects/Aqueous/plugin/helper/zig-out/bin`.
The harness obtains the socket path from the private compositor's child environment
and saves a successful hello before starting DMS. It exercises window activation,
close/fullscreen/move and eligibility failures, workspace widget/rename, keyboard selection, overview, screenshot
geometry, retained helper conflicts, lock/unlock, reconnect and orderly session exit. Native
window captures were 632×612 and 350×1145 for the rotated/fractional negative-origin
case. Runtime and screenshot state paths launched zero `aqueousctl` processes;
22 calls were attributed to retained `aqueous-config` output/cursor operations.
The interceptor saves argv and parent executable for every launch and fails if the
parent is outside that retained helper. Evidence: `/tmp/dms-aqueous-integration-0_4nvb4o`.

Physical hotplug, full lock UI, mixed-scale hardware and new-instance desktop
relaunch remain manual verification. The QML transport limitations above are
explicit deviations from the native hardening requirements in the original plan.
