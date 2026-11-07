# calendar panel (Quickshell)

A square, top-right calendar for the todo board. The clock leads, a lunar-month
line moves under it, weather sits below the line, and the month grid fills the
left side beside the selected day's task list. The task card is deliberately
shorter: a square gif sits underneath it. The taller month grid uses the space
that would otherwise sit empty below the calendar.

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
SettingSlider.qml theme-matched size/opacity/glow slider
SettingField.qml  labelled single-line settings field
SettingToggle.qml labelled switch row for boolean settings
Toggle.qml        small pill switch used by SettingToggle
IconBtn.qml       header and month-navigation buttons
StatChip.qml      clickable today/overdue/month counters
TaskSection.qml   read-only OVERDUE / OPEN / DONE group
TaskRow.qml       one task line with status, repeat and tags
SearchPanel.qml   read-only task search, grouped by due date
DetailOverlay.qml modal shell for the moon and weather detail cards
MoonDetail.qml    phase, illumination and next new/full dates
WeatherDetail.qml current conditions, local hint and three-day outlook
GifTile.qml       framed square gif under the task card
```

Run: `qs -c calendar`
Toggle: `qs -c calendar ipc call calendar toggle`
Open a day: `qs -c calendar ipc call calendar select 2026-11-07`

The installer binds `SUPER + C` to `~/.local/bin/calendar-toggle`. On Ryoku,
where `SUPER + C` is also the shipped center-window chord, the installer moves
that action to `SUPER + ALT + C` through the Ryoku keybind store when it has not
already been remapped. The calendar has a `calendar-toggle` launcher, so either
the keybind or `qs -c calendar ipc call calendar toggle` works.

## Layout

- **Header**: a date badge, a large clock (12/24-hour, with optional seconds),
  the date with its ISO week, today/overdue/month chips, then search, settings
  and close buttons. Today jumps to the current day; overdue jumps to the oldest
  overdue day; month opens the picker. The card drops out from under the Ryoku
  bar at the top-right of the focused monitor.
- **Lunar line**: nine small phase moons mark the synodic cycle. The accent
  track fills to the current moon age, and a larger moon marker travels with it;
  the marker's lit shape, the phase name, illumination and lunar day all follow
  the real phase. Weather sits directly below the line. Both strips are
  optional.
- **Month card**: the grid stretches down the full left column. Every busy day
  shows a count; the tint is accent for open work, warm for overdue and quiet
  when everything is done. Each day still shows up to two due times (or `all`
  for an all-day task), with done lines dimmed and struck through. Hovering a busy day opens a read-only detail
  card with its done/open/overdue summary, progress bar and next four tasks.
  Today has a filled dot, the selected day an accent ring. The week can start on
  Monday or Sunday. Click the month name/year or the `M` key for the month/year
  picker; click outside or close it to return.
- **Tasks card**: the selected day's full list, grouped `OVERDUE`, `OPEN` and
  `DONE`. The card is intentionally shorter than the month card, leaving room
  for the gif below it. The header shows done/total and any
  overdue count, with a completion bar underneath. The optional `NEXT` row shows
  the next upcoming task across the whole board; click it to jump to that day.
  Each row has a read-only status dot, the title, and the due time (or
  `all day`) plus repeat/tag metadata. Clicking the title opens the todo panel.
  The list scrolls when it fills. The calendar is a viewer: it has no add or
  check-off controls. The header search glyph or the `/` key opens a read-only
  search over every task title and tag; results are grouped by due date with
  undated tasks last. Select a dated result to jump to its day, or an undated
  result to open the todo panel.
- **Gif**: one framed square under the task card, aspect-cropped or contained,
  with a hover frame. It hides without moving the task card. Click it to set a
  path in Settings.

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

The sheet is a compact two-column layout and stays fully visible and scrollable
at the 520 px minimum size. It controls:

- **Panel size**: a 520–900 px slider plus S/M/L presets (560/700/800).
- **Opacity**: 50–100%.
- **Glow**: 0–100% accent wash on the panel, cards and selection rings.
- **Fit layout to panel size**: picks compact, comfortable or roomy metrics
  automatically, with 10 px hysteresis at the 660/780 px thresholds.
- **Reduce motion**: stops the card slide and pauses the gif.
- **High contrast**: brighter secondary text and stronger borders.
- **Clock & calendar**: 24/12-hour clock, seconds, Monday or Sunday week start,
  lunar line, weather strip and next-task row visibility.
- **Accent override**: empty uses the Ryoku palette, or a `#rrggbb` colour.
- **GIF**: show/hide it, set its path, and choose cover/contain. No gif is
  bundled (paths and copyright), so the tile shows a clickable placeholder until
  you choose one.
- **Weather**: the city (empty = guess from the network), °C/°F, and a reload
  link.

The panel reads `~/.cache/ryoku/colors.json`, so it follows the Ryoku palette and
accent. Settings are written back to `settings.json` about 400 ms after a change.
Older settings files migrate forward: missing keys use their defaults and are
added on the next save.

The card is square: `panelWidth` in `settings.json` sets both dimensions. The
default is 700 px and the range is 520–900 px. The layout is drawn on a 560 px
canvas and scaled uniformly with the card, so type and controls grow with it.
Automatic fitting uses compact metrics below 660 px, comfortable metrics from
660–779 px, and roomy metrics at 780 px and above; the 10 px hysteresis stops a
card near a threshold from flipping back and forth. Turn the toggle off to keep
the comfortable layout at every size. The card is capped to the available screen
height, with a 38 px top-bar inset.

## Dependencies

- `quickshell` (Qt 6), with `QtQuick.Effects` for the image masks
- `curl` (weather)
- a Nerd Font for the weather glyphs (`JetBrainsMono Nerd Font` is used)
- optional on Ryoku: `ryoku-hub` for moving the stock `SUPER + C` center chord

Tasks live in the todo widget; this panel only reads them.

The panel intentionally leaves out radar/weather-alert feeds, moonrise/set,
fuzzy search, drag rescheduling and a full screen-reader audit. The search and
detail views are read-only and never touch `tasks.json`.
