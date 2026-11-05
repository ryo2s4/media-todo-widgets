# media + todo + calendar (Quickshell)

Three self-contained panels for a Hyprland/Ryoku desktop:

| widget | what it is | shortcut |
|---|---|---|
| `media/` | media player, home dashboard, games, notifications, profile/Special tab | `SUPER + M`, `SUPER + G` |
| `todo/` | right-side todo board with projects, tags, due dates, pomodoro, calendar sheet | `SUPER + S` |
| `calendar/` | month grid of todo due dates, day agenda + quick add, moon / clock / weather tray, one gif | `SUPER + ALT + C` |

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
- **preserves your existing tasks, settings, notifications, weather cache and
  todo backups** when updating;
- installs `~/.local/bin/media-toggle` and `~/.local/bin/calendar-toggle`;
- adds the startup lines and keybinds to `~/.config/hypr/user.lua` when missing;
- starts the panels.

If Hyprland does not see a new keybind immediately, run `hyprctl reload`.

## Calendar

`calendar/` reads the todo board's `tasks.json` live (read-only) and shows every
due task on its day and time. Clicking a day opens its agenda; adding a task or
checking one off goes through the todo panel's IPC, so the todo board remains the
single writer.

Under the month: the real moon phase (calculated from the moon's age), a clock,
and Open-Meteo weather (city in Settings, or automatic IP lookup). The gif under
the tray is a single permanent gif; set its path in the calendar's Settings
(gear in the header) or edit `~/.config/quickshell/calendar/settings.json`. No
gif is bundled (paths and copyright), so the slot shows a clickable placeholder
until you choose one.

The todo board supports due dates and times today: in quick-add use
`Call the bank @tomorrow 17:30`, or edit a task and put `tomorrow 17:30` in the
Due field. The calendar's quick-add creates the same values with a click.

## Data

Everything user-specific stays local:

- `todo/tasks.json`, `todo/state.json`, `todo/status.json`
- `media/settings.json`, `media/special.json`, `media/library.json`,
  `media/notifs.json`, `media/weather.json`
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
