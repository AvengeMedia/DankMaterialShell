# Counter Example

A composite plugin with three surfaces that share one counter:

- `components.dash` (`CounterTab.qml`): a dash tab built on `DashTabComponent`. It hosts a `DashWidgetGrid`, so the dash Edit, Add widget, Reset and Clear All actions work on it. The Reset widget starts in the Add menu (`enabled: false`). `+` and `-` change the count.
- `components.dashCard` (`CounterCard.qml`): an overview card built on `DashCardComponent`. Clicking it opens the tab. Left and Right change the count while it has focus.
- `components.widget` (`CounterWidget.qml`): a bar pill. Left click toggles the dash on the counter tab, right click adds one. The same file works in a dock with no extra code.

The count is stored with `setData("count", value)` / `savePluginData` and read back through `pluginData.count`. Every surface reloads `pluginData` on `pluginDataChanged`, so they stay in sync.

Open the tab from a terminal with `dms ipc call dash open plugin_dashCounterExample`. If the tab is hidden from the tab bar it opens as a detail page with a back button.
