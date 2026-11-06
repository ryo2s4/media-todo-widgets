# calendar panel (Quickshell)

A square, top-right calendar for the todo board. The clock leads, a lunar-month
line moves under it, weather sits below the line, and the month grid shares the
lower half with the selected day's task list. A single square gif is tucked
under the month.

```
shell.qml         window, square layout, adaptive metrics, keyboard, todo bridge
Store.qml         reads todo/tasks.json (read-only) and groups tasks by day
CalendarGrid.qml  compact month grid; counts, overdue/done tone, hover detail
MonthPicker.qml   compact month/year chooser over the month card
MoonLine.qml      lunar-month progress line and phase marker
Moon.qml          real phase drawing (no image set)
WeatherStrip.qml  compact weather row under the moon line
Weather.qml       Open-Meteo + IP geolocation, cached in weather.json
Settings.qml      persisted settings, defaults and migration
SettingsSheet.qml compact two-column settings overlay
SettingSlider.qml theme-matched size/opacity slider
SettingField.qml  labelled single-line settings field
Toggle.qml        small pill switch for the boolean settings
IconBtn.qml       header and month-navigation buttons
StatChip.qml      clickable today/overdue/month counters
TaskSection.qml   read-only OVERDUE / OPEN / DONE group
TaskRow.qml       one task line with status, repeat and tags
SearchPanel.qml   read-only task search, grouped by due date
DetailOverlay.qml modal shell for the moon and weather detail cards
MoonDetail.qml    phase, illumination and next new/full dates
WeatherDetail.qml current conditions, local hint and three-day outlook
```

Run: `qs -c calendar`
Toggle: `qs -c calendar ipc call calendar toggle`
Open a day: `qs -c calendar ipc call calendar select 2026-11-07`

The installer binds `SUPER + ALT + C` to `~/.local/bin/calendar-toggle`.

## Layout

- **Header**: a date badge, a large 24-hour clock, the date with its ISO week,
  today/overdue/month chips, then settings and close buttons. Today jumps to the
  current day; overdue jumps to the oldest overdue day; month opens the picker.
  The card drops out from under the Ryoku top bar at the top-right of the focused
  monitor.
- **Lunar line**: nine small phase moons mark the synodic cycle. The accent
  track fills to the current moon age, and a larger moon marker travels with it;
  the marker's lit shape, the phase name, illumination and lunar day all follow
  the real phase. Weather sits directly below the line.
- **Month card**: the grid is compact. Every busy day shows a count; the tint is
  accent for open work, warm for overdue and quiet when everything is done. Each
  day still shows up to two due times (or `all` for an all-day task), with done
  lines dimmed and struck through. Hovering a busy day opens a read-only detail
  card with its done/open/overdue summary, progress bar and next four tasks.
  Today has a filled dot, the selected day an accent border. Click the month
  name/year or the `M` key for the month/year picker; click outside or close it
  to return.
- **Tasks card**: the selected day's full list, grouped `OVERDUE`, `OPEN` and
  `DONE`. The header shows done/total and any overdue count, with a completion
  bar underneath. The `NEXT` row shows the next upcoming task across the whole
  board; click it to jump to that day. Each row has a read-only status dot, the
  title, and the due time (or `all day`) plus repeat/tag metadata. Clicking
  the title opens the todo panel. The list scrolls when it fills. The calendar
  is a viewer: it has no add or check-off controls. The header search glyph or
  the `/` key opens a read-only search over every task title and tag; results
  are grouped by due date with undated tasks last. Select a dated result to jump
  to its day, or an undated result to open the todo panel.
- **Gif**: one square tile under the month, aspect-cropped rather than stretched.
  Click it to set a path in Settings.

## Keys

| key | action |
|---|---|
| `/` | open task search |
| `Esc` | close search/detail/settings/month picker, then the card |
| `Enter` (in search) | open the first result |
| `Left` / `Right` | previous / next month |
| `Shift + Left` / `Shift + Right` | previous / next day |
| `Shift + Up` / `Shift + Down` | previous / next week |
| `T` | jump to today |
| `M` | open the month/year picker |

The search field keeps focus while open, so `Esc` returns to the calendar.
Shift-arrow navigation crosses month boundaries and updates both the grid and
the selected-day tasks.

The panel never writes `tasks.json` and never adds or checks off a task. Those
actions stay in the todo panel, which remains the only writer and the place to
change due dates or reschedule. The todo quick-add accepts `@tomorrow 17:30`;
the calendar simply shows the resulting day and time.

## Moon and weather

- **Moon**: the phase is calculated from the actual age of the moon (synodic
  month 29.530588853 days, epoch 2000-01-06 18:14 UTC). The terminator is the
  projected edge of the lit half of the sphere, so the crescent grows and
  shrinks correctly through the month. The line is a timeline of that month:
  the filled track and the large marker move with the moon's age. Click the
  lunar line for a detail card with the phase, illumination and approximate
  next new/full dates.
- **Weather**: Open-Meteo, no API key. The place comes from the city in Settings,
  or from an IP lookup when that is empty. The cache lives in `weather.json`
  and refreshes every 30 minutes. The strip shows the current condition, the
  temperature, today's high/low and the place. Click it for current details,
  sunrise/sunset, wind/humidity and the next three days. A conservative local
  heads-up (heavy rain, snow, wind, heat, cold or fog) is labelled as a hint,
  never as an official alert.

Click the gear in the header or the gif tile for Settings. The moon line and
weather strip open their read-only detail cards instead.

The sheet is a compact two-column layout and stays fully visible at the 520 px
minimum size. It controls:

- **Panel size**: a 520–900 px slider plus S/M/L presets (560/700/800).
- **Opacity**: 50–100%.
- **Fit layout to panel size**: picks compact, comfortable or roomy metrics
  automatically, with 10 px hysteresis at the 660/780 px thresholds.
- **Reduce motion**: stops the card slide and pauses the gif.
- **High contrast**: brighter secondary text and stronger borders.
- **Calendar**: accent override (empty uses the Ryoku palette) and the gif path.
  No gif is bundled (paths and copyright), so the slot shows a clickable
  placeholder until you pick one.
- **Weather**: the city (empty = guess from the network), °C/°F, and a reload
  link.

The panel reads `~/.cache/ryoku/colors.json`, so it follows the Ryoku palette and
accent. Settings are written back to `settings.json` about 400 ms after a change.
An older file without the three boolean keys still loads; the missing keys use
their defaults (`autoLayout: true`, `reducedMotion: false`,
`highContrast: false`) and are added on the next save.

The card is square: `panelWidth` in `settings.json` sets both dimensions. The
default is 700 px and the range is 520–900 px. The layout is drawn on a 560 px
canvas and scaled uniformly with the card, so type and controls grow with it.
Automatic fitting uses compact metrics below 660 px, comfortable metrics from
660–779 px, and roomy metrics at 780 px and above; the 10 px hysteresis stops a
card near a threshold from flipping back and forth. Turn the toggle off to keep
the comfortable layout at every size. The card is capped to the available screen
height, with a 38 px top-bar inset.

## Dependencies

- `quickshell` (Qt 6)
- `curl` (weather)
- a Nerd Font for the weather glyphs (`JetBrainsMono Nerd Font` is used)

Tasks live in the todo widget; this panel only reads them.

V1 intentionally leaves out radar/weather-alert feeds, moonrise/set, fuzzy
search, drag rescheduling and a full screen-reader audit. The search and detail
views are read-only and never touch `tasks.json`.
