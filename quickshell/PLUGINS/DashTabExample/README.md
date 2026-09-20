# Stopwatch Example

A standalone dash tab. The manifest uses the single file form, `"type": "dash"` plus `"component"`, the same way a bar widget uses `"type": "widget"`.

What it shows:

- `DashTabComponent` as the root, sized with `implicitHeight` so the dash grows when many laps are shown.
- `live` gating. The display timer only runs while the tab is on screen and the stopwatch is running. Time is computed from stored timestamps, so the stopwatch keeps counting while the dash is closed or another tab is open.
- The plugin state API (`loadPluginState` / `savePluginState`) for runtime data. Nothing goes into settings, so no permissions are needed.
- `focusTarget` and `restoreFocus()`. Opening the tab focuses Start without a focus ring, so Space starts it right away.
- `handleKeyEvent`: Space starts or pauses, L records a lap, R resets.
- `menuActions`: Reset in the tab's edit-mode controls.
- `dash.options`: a toggle for hundredths and a number for how many laps to list, read as `options.hundredths` and `options.laps`.

Open it with `dms ipc call dash open plugin_dashTabExample`.
