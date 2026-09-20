# Progress Example

A standalone overview card: how much of today, this week, this month or this year has passed. The manifest uses the single file form, `"type": "dashCard"` plus `"component"`.

What it shows:

- `DashCardComponent` as the root. It has no tab, so it is not clickable and keyboard navigation skips it.
- A layout for every size in its range (1x1 up to 4x2). `wide` and `tall` come from the card's pixel size against `DashMetrics.gridRowUnit`.
- `live` gating. `SystemClock` is disabled while the dash is hidden.
- `tone` and the card colors (`accentColor`, `contentColor`, `mutedColor`, `chipColor`), so the card follows the Surface, Primary, Secondary and Tertiary tones like the built-in cards.
- `dash.options`: a choice for the period, a toggle for the time left and a choice for the tone. They show up in the card's options sheet in edit mode and under Settings → Dashboard.

Add it from the dash: open the overview, hover the selected page icon, click the pencil, then Add widget.
