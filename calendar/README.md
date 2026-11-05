# calendar panel (Quickshell)

A right-side calendar for the todo board. It shows every task on its due day,
opens the selected day underneath, and then a tray with the moon, a clock and
the weather. A single gif sits under all of it.

```
shell.qml        window, layout, keyboard, settings card, todo bridge
Store.qml        reads todo/tasks.json (read-only) and groups tasks by day
CalendarGrid.qml one month, tasks written inside the day cells
Tray.qml         moon + clock + weather strip
Moon.qml         real phase drawing (no image set)
Weather.qml      Open-Meteo + IP geolocation, cached in weather.json
Settings.qml     gif / city / units, saved in settings.json
```

Run: `qs -c calendar`
Toggle: `qs -c calendar ipc call calendar toggle`
Open a day: `qs -c calendar ipc call calendar select 2026-11-07`

The installer binds `SUPER + ALT + C` to `~/.local/bin/calendar-toggle`.

## Calendar

- The month grid reads `~/.config/quickshell/todo/tasks.json` live. Tasks with
  a `due` timestamp appear on that day, with their time in the cell (or a bar
  for all-day tasks). Done tasks stay visible, struck through and dimmed.
- Click a day to select it. The agenda under the grid shows every task for that
  day; the circle on the left checks it off, the title opens the todo panel.
- The quick-add row sends a task to the todo panel for the selected day. Type a
  title, optionally a time (`18:00`), press Enter. Leave the time empty for an
  all-day task.
- The panel never writes `tasks.json`. Adding and completing go through
  `qs -c todo ipc call todo addTask/toggleTask`, so the todo board remains the
  only writer and both widgets always agree.

The todo board already accepts due dates and times when editing a task:
the Due field understands `today 17:30`, `tomorrow`, `fri`, `2026-11-12 09:00`
and `17:30`. Quick-add accepts the same with `@`.

## Tray

- **Moon**: the phase is calculated from the actual age of the moon
  (synodic month 29.530588853 days, epoch 2000-01-06 18:14 UTC). The terminator
  is the projected edge of the lit half of the sphere, so the crescent grows
  and shrinks correctly through the month. The label shows the phase name,
  illumination percentage and lunar day.
- **Clock**: 24-hour time, seconds, date and week number.
- **Weather**: Open-Meteo, no API key. The place comes from the city in Settings,
  or from an IP lookup when that is empty. The cache lives in
  `weather.json` and refreshes every 30 minutes.

Click the gear in the header (or the empty gif slot) for Settings: the gif path,
the weather city (empty = guess from the network), and °C/°F. No gif is bundled
(paths and copyright), so the slot shows a clickable placeholder until you pick
one. The panel reads `~/.cache/ryoku/colors.json`, so it follows the Ryoku
palette and accent.

## Dependencies

- `quickshell` (Qt 6)
- `curl` (weather)
- a Nerd Font for the weather glyphs (`JetBrainsMono Nerd Font` is used)

Tasks live in the todo widget; this panel only reads them.
