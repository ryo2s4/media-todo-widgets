#!/usr/bin/env python3
"""Print every desktop notification as one JSON line.

It watches Notify calls on the session D-Bus with dbus-monitor, so it works no
matter which notification daemon (or shell) actually displays them.

Line format: {"app": str, "rid": int, "summary": str, "body": str, "t": epoch_ms}
"""
import json
import re
import shutil
import subprocess
import time

FILTER = "type='method_call',interface='org.freedesktop.Notifications',member='Notify'"

# Notify(app_name, replaces_id, app_icon, summary, body, actions, hints, timeout)
PATTERN = re.compile(
    r'string "(?P<app>.*?)"\s+uint32 (?P<rid>\d+)\s+string "(?P<icon>.*?)"'
    r'\s+string "(?P<summary>.*?)"\s+string "(?P<body>.*)"',
    re.S,
)


def emit(block):
    m = PATTERN.search(block)
    if not m:
        return
    d = m.groupdict()
    print(
        json.dumps(
            {
                "app": d["app"],
                "rid": int(d["rid"]),
                "summary": d["summary"],
                "body": d["body"],
                "t": int(time.time() * 1000),
            },
            ensure_ascii=False,
        ),
        flush=True,
    )


def main():
    cmd = ["dbus-monitor", "--session", FILTER]
    if shutil.which("stdbuf"):
        # without line buffering the output would be held back by the pipe
        cmd = ["stdbuf", "-oL"] + cmd
    proc = subprocess.Popen(
        cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, bufsize=1
    )
    collecting = False
    lines = []
    for line in proc.stdout:
        if line.startswith("method call") and "member=Notify" in line:
            if collecting:
                emit("".join(lines))
            collecting = True
            lines = []
            continue
        if collecting:
            # the five leading arguments end where the actions array starts
            if line.startswith("   array ["):
                emit("".join(lines))
                collecting = False
                lines = []
            else:
                lines.append(line)


if __name__ == "__main__":
    main()
