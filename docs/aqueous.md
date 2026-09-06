# Aqueous integration

This working tree integrates DMS with Aqueous master
`2d8b07fb1ff2354ea0c3acddd5cc84ceb823d6eb`. It is development-build support;
no released minimum Aqueous or DMS version has been established.

The tested DMS baseline is `5baef07048656867a374d210d4305911b8a76e4f`, with
common QML `26396ce432d6c71c3f5367438f96f4a8d667e160` unchanged. The current
verification uses Quickshell `2d3b3e9c70ef380dff751b61d334dc88df016c29`, built
locally with its existing `parentWindow` API. Earlier runs used Arch's
`noctalia-qs 0.0.12` with temporary popup compatibility edits; those edits have
been removed. See [the implementation audit](aqueous-minimal-change-audit.md).
The Aqueous compositor, CLI and `aqueous-config` helper were built from the same
pinned master. The helper reports 0.7.1, protocol 1. The system-installed older
Aqueous and helper binaries were not used for integration testing.
The installed Quickshell toplevel metadata exposes no foreign-toplevel identifier,
so the adapter uses Aqueous's own model without a native Quickshell binding change.

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

Put the matching `aqueousctl` and optional `aqueous-config` binaries on DMS's PATH.
Start DMS in the Aqueous session using the project's existing direct-session or
UWSM launch arrangement. Run only one DMS instance for that session.
Other compositors do not launch the Aqueous watcher or configuration helper.

`AqueousService.qml` owns one persistent `aqueousctl shell watch --json` process.
Its reducer validates schema, string IDs/sequences and delta continuity, applies
full replacements/removals atomically, and shares the authoritative model with
shell consumers. Discovery, reconnect backoff with jitter, seat selection and
short-lived action processes also live in this service. There is no Aqueous core
manager, subscription or server API. Backend changes and shell shutdown stop its
processes; a quiet established watcher has no timer or polling subprocess.

Quickshell's `SplitParser` reassembles complete lines, preserving split UTF-8.
The pinned `aqueousctl` validates bounded UTF-8 batches before emitting NDJSON;
QML additionally checks complete record and retained model sizes. Quickshell does
not expose a pre-delimiter byte limit or raw-byte validity check on this parser.
Consequently the direct service relies on the supported CLI for those guarantees;
it does not independently bound a broken CLI's unterminated output. Enforcing that
boundary independently requires a Quickshell parser capability.

Mutation arguments are arrays, never shell command strings. The service validates
the captured session, explicit seat, capabilities, lock and current target before
dispatch. Disconnects disable stale-ID actions and require a fresh snapshot.
Commands connect directly through `aqueousctl`; the current CLI has no expected-session
argument, so a restart between validation and the child connecting cannot be made
atomic by QML. Close and exit return `accepted`, while window removal follows the
stream. Timed-out mutations are not automatically retried. Qt may exit on Wayland
disconnect before the shell can display the orderly-logout acknowledgement.

Standalone screenshots obtain one fresh snapshot in `core/internal/screenshot`.
Core keybind tooling invokes the helper from its existing provider package. Their
only shared process utility is a bounded, short-lived JSON command runner.

All persistent writes go through `aqueous-config validate/apply --shell dms
--request -`, with JSON on stdin and `expected_generation`. The backup directory
passed to the helper is `$XDG_CONFIG_HOME/DankMaterialShell/aqueous-backups`;
the helper decides when backups are required. Blur supplies a managed TOML block
through the helper's `raw_files.rules` request; DMS never writes the file directly.
Display previews retain the previous live configuration and refuse to revert over
external changes or output recreation. A failed/uncertain preview is reconciled
against live state before offering Keep/Revert. A conflict retains the draft until
the user explicitly discards it and reloads.

### Background blur

When `ext-background-effect-v1` is unavailable, DMS can control Aqueous layer blur
through its existing Background Blur toggle. This path was tested with the pinned
0.7.1 helper. It requires an active Aqueous shell connection and a helper exposing
the validated DMS-mode configuration contract, `raw_files.rules`, and the
`blur.enabled` schema field. Older helpers without that contract remain unavailable.

Enable global blur in Aqueous's `wm.toml` first:

```toml
[blur]
enabled = true
```

Use Reload in DMS's Background Blur settings after changing Aqueous configuration.
Set DMS surface opacity below 100% to see the effect. DMS does not alter Aqueous's
global blur setting or application rules.

The backend prepends a block delimited by `# BEGIN DMS BACKGROUND BLUR` and
`# END DMS BACKGROUND BLUR` to `rules.toml`. Aqueous uses the first matching layer
rule, so the block controls `dms:*` namespaces before user wildcard rules. It
excludes click catchers, dismissal surfaces, exclusion zones, wallpaper blur,
lock/DPMS fades, desktop widgets and monitor identification. The separate frame
blur preference controls `dms:frame`. Layer-owned XDG popups follow their parent.
Regions, clipping and rounded blur shapes are deliberately not reproduced.

Existing content outside the block is retained byte-for-byte. Keep the managed
block at the start of the file; malformed or moved markers produce an error.
Rules files with root-level assignments cannot be safely prefixed and are rejected.
Disabling blur writes explicit false rules so later wildcard rules cannot force it
back on. An initially disabled preference with no managed block does not write.
The rules persist across DMS restarts; protocol support, if available later, removes
the managed block and restores the standard protocol path.

Changes use fresh snapshots and generation-checked validate/apply calls. Errors
appear in settings with explicit Retry; failed or uncertain writes are not retried
automatically. Updates run on startup, setting changes, reconnect and explicit
Reload/Retry. There is no polling process or idle timer. External rule edits are
reconciled on the next such event.

Run the focused tests with:

```sh
node quickshell/tests/aqueous-blur.test.mjs
AQUEOUS_BLUR_TEST_HELPER=/path/to/aqueous-config \
  node quickshell/tests/aqueous-blur.test.mjs
```

The optional helper test writes only to a temporary configuration directory. It
checks validation without writes, enable/disable, stale generations and preservation
of unrelated rules and global blur. Offscreen QML verification also exercised the
production services together with the real helper: startup, toggle/frame updates,
idle behavior and disconnect. These checks do not verify compositor rendering.

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
configuration changed (for example, DMS blur rules), the operation uses the new
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
configuration paths before sharing output. Missing CLI/protocol/helper support is
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
typed `command` method; output runtime IDs are resolved to connector names there.
Settings use `AqueousConfigService` and direct stdin helper requests. See the
[complete contract and schema](aqueous-integration-plan.md) for protocol semantics.

## Verification

The following passed against the pinned build on 2026-09-05:

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
