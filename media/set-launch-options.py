#!/usr/bin/env python3
"""Set a Steam game's launch options by editing localconfig.vdf.

usage: set-launch-options.py [--close] APPID OPTIONS

Steam keeps launch options in userdata/<id>/config/localconfig.vdf and rewrites
that file when it exits, so Steam has to be closed while this runs. With --close
the script asks Steam to shut down first and waits for it.

Prints one line: OK <files changed>, STEAM_RUNNING, NOFILES or ERR <message>.
The first time a file is edited a copy is kept next to it as localconfig.vdf.bak-media.
"""
import glob
import os
import re
import shutil
import subprocess
import sys
import time


def steam_running():
    return subprocess.call(["pgrep", "-x", "steam"], stdout=subprocess.DEVNULL) == 0


def close_steam(timeout=40):
    subprocess.Popen(["steam", "-shutdown"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    end = time.time() + timeout
    while time.time() < end:
        if not steam_running():
            time.sleep(1.0)
            return True
        time.sleep(0.5)
    return not steam_running()


def esc(s):
    return s.replace("\\", "\\\\").replace('"', '\\"')


KEY_ONLY = re.compile(r'^"((?:[^"\\]|\\.)*)"$')


def indent_of(line):
    return line[: len(line) - len(line.lstrip())]


def edit(path, appid, opts):
    with open(path, encoding="utf-8") as f:
        lines = f.read().split("\n")

    # map every block path to (open brace line, close brace line)
    stack = []
    pending = None
    blocks = {}
    for i, line in enumerate(lines):
        t = line.strip()
        if t == "{":
            stack.append((pending, i))
            pending = None
        elif t == "}":
            if not stack:
                return False
            key, oi = stack.pop()
            blocks[tuple(k for k, _ in stack) + (key,)] = (oi, i)
        else:
            m = KEY_ONLY.match(t)
            pending = m.group(1) if m else None

    apps = None
    for p, rng in blocks.items():
        if len(p) >= 2 and p[-2].lower() == "steam" and p[-1].lower() == "apps":
            apps = (p, rng)
            break
    if apps is None:
        return False
    apps_path, (a_open, a_close) = apps

    new_line_value = '"LaunchOptions"\t\t"%s"' % esc(opts)
    app_path = apps_path + (appid,)
    if app_path in blocks:
        o, c = blocks[app_path]
        child_ranges = [rng for p, rng in blocks.items() if len(p) == len(app_path) + 1 and p[: len(app_path)] == app_path]
        found = None
        for i in range(o + 1, c):
            if any(a <= i <= b for a, b in child_ranges):
                continue
            if re.match(r'^\s*"LaunchOptions"\s', lines[i]):
                found = i
                break
        child_indent = indent_of(lines[o]) + "\t"
        if opts == "":
            if found is not None:
                del lines[found]
        elif found is not None:
            lines[found] = child_indent + new_line_value
        else:
            lines.insert(o + 1, child_indent + new_line_value)
    else:
        if opts == "":
            return True
        ind = indent_of(lines[a_open]) + "\t"
        block = [ind + '"%s"' % appid, ind + "{", ind + "\t" + new_line_value, ind + "}"]
        lines[a_open + 1:a_open + 1] = block

    bak = path + ".bak-media"
    if not os.path.exists(bak):
        shutil.copy2(path, bak)
    tmp = path + ".tmp-media"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    os.replace(tmp, path)
    return True


def main():
    args = sys.argv[1:]
    close = False
    if args and args[0] == "--close":
        close = True
        args = args[1:]
    if len(args) < 1:
        print("ERR usage: set-launch-options.py [--close] APPID OPTIONS")
        return 2
    appid = args[0]
    opts = args[1] if len(args) > 1 else ""
    if not re.fullmatch(r"\d+", appid):
        print("ERR bad app id")
        return 2

    if steam_running():
        if not close:
            print("STEAM_RUNNING")
            return 3
        if not close_steam():
            print("ERR Steam did not close in time")
            return 3

    home = os.path.expanduser("~")
    roots = []
    for r in (home + "/.local/share/Steam", home + "/.steam/steam"):
        rr = os.path.realpath(r)
        if os.path.isdir(rr) and rr not in roots:
            roots.append(rr)
    files = []
    for r in roots:
        files += glob.glob(os.path.join(r, "userdata", "*", "config", "localconfig.vdf"))
    if not files:
        print("NOFILES")
        return 4

    changed = 0
    try:
        for f in files:
            if edit(f, appid, opts):
                changed += 1
    except Exception as e:  # noqa: BLE001
        print("ERR %s" % e)
        return 5
    print("OK %d" % changed)
    return 0


if __name__ == "__main__":
    sys.exit(main())
