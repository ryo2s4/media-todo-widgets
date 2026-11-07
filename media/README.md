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

## Special (the private fourth tab)

The Special page is laid out 35% larger than the rest of the panel, so its dense labels and controls stay
readable at the default panel width. The outer panel tabs are unchanged.

A vault for two people. It stays locked until you type the passphrase, and it is really encrypted on disk:
`vault.gpg` is GPG symmetric AES-256 over a `tar.zst` archive, with maximum key stretching (SHA512, 65M).
While unlocked the contents live only in a private `0700` folder under `$XDG_RUNTIME_DIR` and are deleted
when the tab locks. The passphrase never appears on a command line; it is piped to gpg over stdin/an env fd.

First use: the Special tab is hidden. Go to **Settings > Look**, scroll to the bottom, and tap **About** seven
times. The tab appears; open it, pick a passphrase (at least 12 characters, not only digits), repeat it, Return.
The vault is created in `~/Pictures/special` by default; change the folder in Settings > Special. The passphrase
cannot be recovered, so keep a copy of `vault.gpg` and remember the phrase.

The tab is hidden again by **Settings > Special > Hide the tab behind the knock** (or "Hide it now" while it is
revealed); hiding also locks the vault. Turning that switch off makes the tab permanent. This is only a hiding
trick, not extra encryption.

- **Us**: a banner, your device picture (`~/.face`) bottom-left, your partner's photo bottom-right, days since
  you met and until you meet, the small countdowns, and today's memory. Click the banner to choose or replace it
  (PNG/JPG/GIF/WebP, stored inside the vault); the image drifts slowly. Names, birthdays and the optional
  partner details (hobbies, age, weight) live in Settings > Special, and the Us page shows them in a small
  **About** card. Leave the age empty to calculate it from the partner's birthday. These details stay inside
  the encrypted vault.
- **Memories**: the photo grid. "+ photo" copies a picture into the vault, "folder" imports a whole folder.
  Open one to edit caption, date and city, favourite it (F), step with Left/Right. The viewer has a visible
  **delete** action plus a separate **close** button; the Delete key still removes, and Esc also closes.
- **Words**: quotes and letters. A sealed letter is encrypted with everything else but is not shown until its date.
- **Together**: shared bucket list, a deck of long-distance date ideas, and the daily two-way mood check-in.
- **Data**: change folder, lock now, copy the vault as a backup, export a plain HTML/Markdown memory book,
  and delete the vault. The export is **not** encrypted - it is a normal photo album, so store it accordingly.

Closing the panel locks the vault (toggle in Settings > Special), and it auto-locks after the chosen number of
minutes. The 4 key opens the tab only while it is revealed. Photos and the banner are copied into the vault when
added, so the original folder is only an import source. `special.json` stores non-secret preferences (folder,
auto-lock, last section, whether the tab is revealed) only.
