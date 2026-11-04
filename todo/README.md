# todo panel (Quickshell)

Right-side slide-in todo board. Install under `~/.config/quickshell/todo/`.

```
shell.qml     window, layout, keyboard, overlays
Store.qml     all state and logic (no UI)
TaskRow.qml   one task row (+ expanded editor)
Sheet.qml     floating card used by the extra views
Sheets.qml    insights, calendar, tags, templates, archive, plan, palette, focus
IconBtn.qml   glyph button
Toggle.qml    on/off switch
```

Run: `qs -c todo`. Control: `qs -c todo ipc call todo <toggle|open|hide|review|stats|calendar|tags|templates|archive|plan|palette|menu|focus|select|settings|sheets|importNow>`.

## Files it writes (all in this folder)

| file | purpose |
|---|---|
| `tasks.json` | the tasks |
| `state.json` | goal, streak, stats, archive, timer state, settings |
| `status.json` | snapshot for the bar plugin (urgent count, current task, timer) |

### tasks.json

An array of task objects. Unknown fields are ignored; missing fields get defaults,
so older files (with `prio` instead of `quad`) keep loading.

```json
{
  "text": "Call the bank",
  "quad": 3,
  "done": false,
  "ord": 12,
  "pos": 12,
  "due": 1793000000000,
  "repeat": "days:1,3,5",
  "note": "ask about the card",
  "subs": [{ "t": "find number", "d": true }],
  "tags": ["admin"],
  "pomos": 2,
  "doneAt": 0,
  "created": 1792900000000,
  "stage": 0,
  "reminded": false,
  "snooze": 0,
  "focusMs": 900000
}
```

| field | meaning |
|---|---|
| `quad` | 0 Today, 1 End of week, 2 No specific time, 3 Urgent |
| `ord` | unique id, never reused |
| `pos` | sort key inside a box (float, smaller = higher); done tasks always sort last |
| `due` | epoch milliseconds, `0` = none. Date-only dues are stored as 23:59 local time |
| `repeat` | `""`, `"daily"`, `"weekly"` or `"days:<0-6,...>"` (0 = Sunday) |
| `stage` | auto-move progress: 0 none, 1 moved to Today, 2 moved to Urgent (so a manual drag is not undone) |
| `reminded` | the "due in 15 min" notification was sent |
| `snooze` | epoch ms; reminders and auto-move are paused until then (0 = not snoozed) |
| `focusMs` | focus time logged on this task, in milliseconds |

### state.json

```json
{
  "goal": 5, "streak": 3, "lastGoalDay": "2026-10-28", "goalHitDay": "2026-10-28",
  "doneLog": { "2026-10-28": 6 },
  "focusLog": { "2026-10-28": 75 },
  "archive": [],
  "lastReview": "2026-10-25",
  "muted": false, "autoStart": false,
  "exportPath": "/home/you/Documents/todo-export.md",
  "importPath": "/home/you/Documents/todo-import.md",
  "wipLimit": 0, "celebrateEach": false, "soundDone": true, "soundTimer": true,
  "templates": [{ "text": "Weekly review", "quad": 0, "repeat": "weekly", "tags": ["admin"], "subs": [], "note": "" }],
  "lastPlanDay": "2026-10-28", "accentCustom": "",
  "timer": { "modeIndex": 0, "remaining": 1500, "running": false, "endAt": 0, "sessions": 2, "activeTaskId": -1 }
}
```

`doneLog` is tasks completed per day, `focusLog` is focus minutes per day.

### status.json

```json
{ "urgent": 2, "pending": 9, "running": true, "endAt": 1792900000000,
  "remaining": 1320, "mode": "Pomodoro", "task": "Call the bank",
  "doneToday": 3, "goal": 5, "streak": 4, "updated": 1792900000000 }
```

For a running timer use `endAt` (epoch ms) rather than `remaining`.

## Quick-add syntax

`!call mom @17:30 #family *daily`

| token | effect |
|---|---|
| `!` at the start | Urgent |
| `#t` `#w` `#s` | Today / End of week / No specific time |
| `#word` | tag |
| `@tomorrow` `@fri` `@2026-11-05` `@17:30` | due date and/or time (combine: `@fri @09:00`) |
| `@in2h` `@in 3d` `@tonight` `@noon` `@eod` `@next fri` | relative dues |
| `*daily` `*weekly` `*weekdays` `*mon,wed` | repeat |

With a due date and no explicit box, the box is chosen from the date.

## Behaviour notes

- Every minute: tasks due today move to Today once, overdue ones move to Urgent once,
  and a notification is sent 15 minutes before a timed due.
- Completing a repeating task creates the next occurrence.
- Timer: after every 4th focus session the break is a long break (15 min).
- Deep focus turns Do Not Disturb on (swaync, mako or dunst) and restores it afterwards.
- Reaching the daily goal plays a GIF from `~/Pictures/pc/Todo-gifs/goal` if that folder
  exists, otherwise from the main GIF folder.
- Sundays (or `ipc call todo review`): weekly summary, and done tasks older than 7 days
  move into `archive` in `state.json`.

## Keys (click the panel once first so it has keyboard focus)

Arrows navigate, Space done, E edit, Enter expand, Delete remove, Shift+arrows move the
task (Shift+Up/Down reorders, Shift+Left/Right changes box), N new task, Ctrl+F search,
Ctrl+K command palette, Ctrl+A select all visible, Ctrl+Z undo, Ctrl+1..4 pick the box
for new tasks, Esc closes / cancels.

## Extra views

The `...` button in the header (or the IPC commands above) opens:

- **Insights** – 10-week activity heatmap, last 14 days, focus totals, per-tag counts.
- **Calendar** – month grid with due dots; click a day to filter the board to it.
- **Tags / projects** – open/total per tag; click to filter.
- **Templates** – save a task as a template in its expanded editor, re-add it here.
- **Archive** – restore or delete tasks that rolled out of the weekly review.
- **Plan today** – pick tasks from End of week / No specific time into Today. The
  header shows a `Plan` prompt until you use it once that day.
- **Command palette** – filter tasks and jump to any view or action.
- **Focus mode** – full-panel timer with the active task.

Select mode (menu, Ctrl+A or IPC) shows checkboxes; a bulk bar completes, moves or
deletes the selected tasks.

## Snooze, import, backups

Each task's expanded editor has snooze buttons (15m, 1h, tonight, tomorrow). A snoozed
task is skipped by due reminders and auto-move until the snooze expires.

Settings has an import path (Markdown `- [ ]` checklists and todo.txt `(A) ...` lines)
and an Import now button. The panel also runs `importNow` over IPC.

On every start it copies `tasks.json` and `state.json` into `backups/` (last 15 kept).
Settings also has sound toggles per event, a celebrate-every-task GIF toggle, a WIP
limit for the Urgent box, and accent presets.

## Blur

The panel namespace is `todo-panel`. Add a Hyprland layer rule for it the same way Ryoku
does for its own surfaces (the syntax depends on the Hyprland version).
