# calendar panel (Quickshell)

A square, top-right calendar for the todo board. The clock leads, a lunar-month
line moves under it, weather sits below the line, and the month grid shares the
lower half with the selected day's task list. A single square gif is tucked
under the month.

```
shell.qml         window, square layout, keyboard, settings card, todo bridge
Store.qml         reads todo/tasks.json (read-only) and groups tasks by day
CalendarGrid.qml  compact month grid; due times in the day cells
MoonLine.qml      lunar-month progress line and phase marker
Moon.qml          real phase drawing (no image set)
WeatherStrip.qml  compact weather row under the moon line
Weather.qml       Open-Meteo + IP geolocation, cached in weather.json
Settings.qml      gif / city / units, saved in settings.json
IconBtn.qml       header and month-navigation buttons
StatChip.qml      today/month counters in the header
```

Run: `qs -c calendar`
Toggle: `qs -c calendar ipc call calendar toggle`
Open a day: `qs -c calendar ipc call calendar select 2026-11-07`

The installer binds `SUPER + ALT + C` to `~/.local/bin/calendar-toggle`.

## Layout

- **Header**: a date badge, a large 24-hour clock, date/week, today and month
  counters, then settings and close buttons. The card drops out from under the
  Ryoku top bar at the top-right of the focused monitor.
- **Lunar line**: nine small phase moons mark the synodic cycle. The accent
  track fills to the current moon age, and a larger moon marker travels with it;
  the marker's lit shape, the phase name, illumination and lunar day all follow
  the real phase. Weather sits directly below the line.
- **Month card**: the grid is compact. Each day shows up to two due times (or
  `all` for an all-day task) and a small count when more are hidden. Today has a
  filled dot and the selected day has an accent border. Done tasks stay visible,
  dimmed and struck through.
- **Tasks card**: the selected day's full list. The circle on the left checks a
  task off; the title opens the todo panel; the time line shows the due time (or
  `all day`). The list scrolls when it fills. The quick-add row at the bottom
  sends a task to the todo panel for the selected day. Type a title, optionally
  a time (`18:00`), press Enter. Leave the time empty for an all-day task.
- **Gif**: one square 96 px tile under the month, aspect-cropped rather than
  stretched. Click it to set a path in Settings.

The panel never writes `tasks.json`. Adding and completing go through
`qs -c todo ipc call todo addTask/toggleTask`, so the todo board remains the
only writer and both widgets always agree.

The todo board already accepts due dates and times when editing a task:
the Due field understands `today 17:30`, `tomorrow`, `fri`, `2026-11-12 09:00`
and `17:30`. Quick-add accepts the same with `@`.

## Moon and weather

- **Moon**: the phase is calculated from the actual age of the moon (synodic
  month 29.530588853 days, epoch 2000-01-06 18:14 UTC). The terminator is the
  projected edge of the lit half of the sphere, so the crescent grows and
  shrinks correctly through the month. The line is a timeline of that month:
  the filled track and the large marker move with the moon's age.
- **Weather**: Open-Meteo, no API key. The place comes from the city in Settings,
  or from an IP lookup when that is empty. The cache lives in `weather.json`
  and refreshes every 30 minutes. The strip shows the current condition, the
  temperature, today's high/low and the place.

Click the gear in the header, the weather strip, or the gif tile for Settings:
the gif path, the weather city (empty = guess from the network), and °C/°F. No
gif is bundled (paths and copyright), so the slot shows a clickable placeholder
until you pick one. The panel reads `~/.cache/ryoku/colors.json`, so it follows
the Ryoku palette and accent.

The card is square: `panelWidth` in `settings.json` sets both dimensions. The
default is 560 px. The top-bar inset is 38 px.

## Dependencies

- `quickshell` (Qt 6)
- `curl` (weather)
- a Nerd Font for the weather glyphs (`JetBrainsMono Nerd Font` is used)

Tasks live in the todo widget; this panel only reads them.
