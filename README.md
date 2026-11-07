# media + todo + calendar (Quickshell)

Three self-contained panels for a Hyprland/Ryoku desktop:

| widget | what it is | shortcut |
|---|---|---|
| `media/` | media player, home dashboard, games, notifications, profile/Special tab | `SUPER + M`, `SUPER + G` |
| `todo/` | right-side todo board with projects, tags, due dates, pomodoro, calendar sheet | `SUPER + S` |
| `calendar/` | compact square calendar: full-height month grid + short day list, gif, lunar line, clock, weather | `SUPER + C` |

## Install

```bash
git clone https://github.com/ryo2s4/media-todo-widgets.git
cd media-todo-widgets
bash install.sh
```

The installer can also be run from a downloaded copy; it clones the repo when it
is not sitting next to the widget folders.

It:

- checks for `quickshell`, `git`, `curl` (and the media panel's optional
  `gpg`/file-picker tools), installing them with pacman/apt/dnf when possible;
- copies the three widgets to `~/.config/quickshell/`;
- **preserves your existing tasks, settings, music favourites, scratch note,
  cava config, notifications, weather cache and todo backups** when updating;
- installs `~/.local/bin/media-toggle` and `~/.local/bin/calendar-toggle`;
- adds the startup lines and keybinds to `~/.config/hypr/user.lua` when missing;
- starts the panels.

If Hyprland does not see a new keybind immediately, run `hyprctl reload`.

## Calendar

`calendar/` is a square card at the top-right of the focused monitor. It reads
the todo board's `tasks.json` live (read-only): the compact month grid shows due
times and task counts on their days, and the task column beside it holds the
selected day's full list, grouped overdue/open/done. Busy days are tinted for
open work, overdue work or all-done days; hovering one opens a small summary
and task preview. The header chips jump to today or the oldest overdue day,
and the month name opens a month/year picker. The header search glyph or `/`
opens a read-only task search grouped by due date; selecting a dated result
jumps to that day, while an undated result opens todo. Shift+Left/Right moves by
day and Shift+Up/Down by week. The calendar is a viewer: adding, completing and
rescheduling stay in the todo panel, which remains the single writer.

The clock sits at the top; underneath it a lunar-month line moves with the real
moon's age and changes its phase shape as the month turns. Click the line for
phase, illumination and next new/full dates. Weather (Open-Meteo; city in
Settings, or automatic IP lookup) sits directly under that line; click it for
current details, sunrise/sunset, wind/humidity, a conservative local hint and a
three-day outlook. The month card fills the full left column, while the shorter
task card has a framed square gif underneath it. Set the gif path in the
calendar's Settings (gear in the header) or edit
`~/.config/quickshell/calendar/settings.json`. No gif is bundled (paths and
copyright), so the tile shows a clickable placeholder until you choose one.

The card is resizable from 520–900 px (700 px by default, with S/M/L presets
560/700/800). The task column shows a completion bar, an optional `NEXT` row for
the next upcoming task across the board, and repeat/tag metadata on each row;
click the `NEXT` row to jump to that day. The settings sheet also has opacity,
accent glow, automatic compact/comfortable/roomy layout, reduced motion, high
contrast, clock format and seconds, week start, moon/weather/next/gif visibility,
gif fit, accent override and weather units. Existing settings files migrate
forward automatically; the installer still preserves the whole
`calendar/settings.json`.

`SUPER + C` opens the calendar. On Ryoku the stock center-window action moves to
`SUPER + ALT + C` so both actions remain available; the installer applies that
mapping through `ryoku-hub` when it is present and not already customised.

The todo board supports due dates and times: in quick-add use
`Call the bank @tomorrow 17:30`, or edit a task and put `tomorrow 17:30` in the
Due field. The calendar only displays the result.

## Data

Everything user-specific stays local:

- `todo/tasks.json`, `todo/state.json`, `todo/status.json`
- `media/settings.json`, `media/special.json`, `media/library.json`,
  `media/favorites.json`, `media/notifs.json`, `media/note.txt`,
  `media/cava.conf`, `media/weather.json`
- `calendar/settings.json`, `calendar/weather.json`

Repositories are shipped with clean defaults, not the author's tasks, location,
notifications or profile. The installer restores an existing copy over the
defaults.

## Requirements

- Quickshell 0.3+ on Qt 6
- Hyprland (the panels use layer-shell and Hyprland's monitor/focus APIs)
- `curl` for weather
- a Nerd Font for glyphs (the widgets use `JetBrainsMono Nerd Font`)
- optional for the media Special tab: `gpg` and `zenity`/`kdialog`/`yad`

See each widget's `README.md` for the internals.
