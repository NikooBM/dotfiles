#!/usr/bin/env python3
import json
import subprocess
import sys
import os

ICONS = {
    "vivaldi-stable":        "󰖟",
    "vivaldi":               "󰖟",
    "firefox":               "󰈹",
    "chromium":              "󰊯",
    "kitty":                 "",
    "code":                 "󰨞",
    "obsidian":             "󰎚",
    "thunar":               "󰉋",
    "libreoffice-calc":     "󰈛",
    "libreoffice-writer":   "󰈙",
    "libreoffice-impress":  "󰈩",
    "steam":                "󰓓",
    "discord":              "󰙯",
    "telegram-desktop":     "󰭹",
    "org.telegram.desktop": "󰭹",
    "spotify":              "󰓇",
    "vlc":                  "󰕼",
    "mpv":                  "󰎁",
    "gimp":                 "",
    "inkscape":             "󰂫",
    "blender":              "󰂫",
    "pavucontrol":          "󰕾",
    "blueman-manager":      "󰂯",
    "org.pwmt.zathura":     "󰈦",
    "evince":               "󰈦",
    "nautilus":             "󰉋",
}
DEFAULT_ICON = "󰣆"

CSS_PATH = os.path.expanduser("~/.config/hypr/scripts/switcher.css")

def get_icon(cls):
    cls = cls.lower()
    for key, icon in ICONS.items():
        if key in cls:
            return icon
    return DEFAULT_ICON

def truncate(text, n=52):
    return text if len(text) <= n else text[:n-1] + "…"

def main():
    result = subprocess.run(["hyprctl", "clients", "-j"], capture_output=True, text=True)
    clients = json.loads(result.stdout)

    visible = [c for c in clients if c.get("mapped") and not c.get("hidden")]
    visible.sort(key=lambda c: c.get("focusHistoryID", 9999))

    if not visible:
        sys.exit(0)

    lines = []
    addr_map = {}

    for i, c in enumerate(visible, 1):
        icon  = get_icon(c.get("class", ""))
        cls   = c.get("class", "unknown")
        title = truncate(c.get("title", "sin título"))
        ws    = c.get("workspace", {}).get("name", "?")
        addr  = c.get("address", "")
        line  = f"{i:>2}.  {icon}  {cls:<18}  {title}  [ws {ws}]"
        lines.append(line)
        addr_map[line] = addr

    cmd = [
        "wofi", "--dmenu",
        "--prompt", "󰖯  Ventanas",
        "--insensitive",
        "--cache-file", "/dev/null",
        "--width",  "760",
        "--height", "420",
        "--no-actions",
        "--define", "dynamic_lines=false",
    ]
    if os.path.exists(CSS_PATH):
        cmd += ["--style", CSS_PATH]

    proc = subprocess.run(cmd, input="\n".join(lines), capture_output=True, text=True)
    selected = proc.stdout.strip()

    if selected and selected in addr_map:
        subprocess.run(["hyprctl", "dispatch", "focuswindow", f"address:{addr_map[selected]}"])

if __name__ == "__main__":
    main()
