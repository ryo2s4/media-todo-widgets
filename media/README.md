# media panel (Quickshell)

Install: unzip into `~/.config/quickshell/media/`. The code files go flat in that folder; the zip also has a
`frames/` sub-folder (profile picture frames) that must stay as it is. Then

    qs -c media
    qs -c media ipc call media toggle      # also: show, hide, home, games, music, settings

The panel comes out of the bottom-left corner. Settings are behind the gear icon and are saved in
`~/.config/quickshell/media/settings.json`.

## What it needs

| for | needs |
|---|---|
| everything | quickshell, Hyprland, the font "JetBrainsMono Nerd Font" |
| notifications drawer | python3, dbus-monitor |
| weather | curl (Open-Meteo, no key) |
| lyrics | curl (LRCLIB, no key) |
| music visualizer | cava (optional) |
| volume / brightness | wpctl, brightnessctl (optional) |
| Steam, Discord, Proton VPN buttons | steam, discord, protonvpn-app (proton-vpn-cli for one-click connect) |
| Browse buttons in Settings | zenity, kdialog or yad (optional; paths can be pasted instead) |
| "Not installed" games | a free Steam Web API key in Settings > Games |
| per-game launch options | python3; prime-run, gamemoderun, mangohud if you want those toggles |

## Files it writes (all in the media folder)

settings.json, favorites.json, library.json (owned games cache), weather.json (weather cache),
notifications.json, note.txt (scratch note), cava.conf, status.json is written by the Todo panel.
Steam launch options are written into Steam's own `localconfig.vdf` (a `.bak-media` copy is kept).

## Keys (click the panel once first)

1 / 2 / 3 or Tab switch tabs, Esc close, N show/hide notifications, C clear notifications.
The notification history is hidden by default so the panel body gets the full height.
Home: S Steam, D Discord, V VPN.
Games: arrows, Enter play or install, F favorite, S sort, A category, R surprise me, / search.
Music: Space, Left/Right, Up/Down volume, L lyrics.

## Profile picture frames

Pick one in Settings > Profile, or hover your picture on the Home tab and press "Frame" to step through them.
They are in `frames/` and listed in `frames/frames.json`:

    { "id": "hud", "name": "HUD ring", "file": "hud.png", "kind": "ring", "hole": 0.81, "cx": 0.50, "cy": 0.50 }

- kind `ring`: a PNG with a transparent middle; the picture is placed in the middle (`hole` = diameter of the
  middle as a fraction of the image width, `cx`/`cy` = its centre).
- kind `anim`: an animated WebP (add `"gif": "name.gif"` as a fallback).
- kind `sticker`: a small decoration placed on the top-right edge of the picture.

Your own frame: Settings > Profile > "Your own frame", pick a PNG with a transparent middle and set the size of the middle.

it contains a little secret if you are married or engaged :3
enjoy the widgets
