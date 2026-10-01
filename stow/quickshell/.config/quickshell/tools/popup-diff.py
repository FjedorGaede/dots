#!/usr/bin/env python3
"""Compare every IPC-openable panel of the live shell vs the preview instance.

Dev tool for the refactor (docs/REFACTOR.md §11). For each panel: screenshot
without popup (on an empty workspace, so only the wallpaper is behind), open it on the live instance, screenshot, close; same on the
preview instance. The popup rectangle is found by diffing against the
no-popup screenshot, then both crops are compared (size + pixels).

Usage: popup-diff.py [panel ...]   (default: all)
Images land in /tmp/qs-popup-diff/<panel>-{live,preview,diff}.png
"""
import os, subprocess, sys, time
import numpy as np
from PIL import Image

PREVIEW = os.path.expanduser("~/dots-qs-refactor/stow/quickshell/.config/quickshell")
PANELS = sys.argv[1:] or ["audio", "wifi", "bluetooth", "notifications", "home", "network"]
OUT = "/tmp/qs-popup-diff"
os.makedirs(OUT, exist_ok=True)

def shot():
    p = f"{OUT}/_tmp.png"
    subprocess.run(["grim", p], check=True)
    return np.asarray(Image.open(p).convert("RGB")).astype(int)

def ipc(preview, target, fn):
    cmd = ["qs", "ipc"] + (["-p", PREVIEW] if preview else []) + ["call", target, fn]
    subprocess.run(cmd, check=False, capture_output=True)

def _run(mask1d):
    # largest contiguous run of True
    best, cur, bs = (0, 0), 0, 0
    for i, v in enumerate(mask1d):
        if v:
            if cur == 0: bs = i
            cur += 1
            if cur > best[1] - best[0]: best = (bs, i + 1)
        else:
            cur = 0
    return best

def bbox(a, b):
    # run on an empty workspace (static wallpaper) → every change is the popup
    d = np.abs(a - b).sum(axis=2) > 30
    # (no bar-strip masking: live popups overlap the preview bar strip;
    #  a clock minute tick between shots can cause a false positive — rerun)
    if d.sum() < 500:
        return None
    y0, y1 = _run(d.sum(axis=1) > 0)
    x0, x1 = _run(d[y0:y1].sum(axis=0) > 0)
    return y0, y1, x0, x1

def capture(preview, panel):
    base = shot()
    ipc(preview, panel, "open"); time.sleep(0.7)
    img = shot()
    ipc(preview, panel, "close"); time.sleep(0.5)
    bb = bbox(base, img)
    return None if bb is None else img[bb[0]:bb[1], bb[2]:bb[3]]

import json as _json
_ws = _json.loads(subprocess.run(["hyprctl", "activeworkspace", "-j"], capture_output=True, text=True).stdout)["id"]
# NB: Hyprland here uses the Lua config → hyprctl dispatch takes hl.dsp.* calls
def _focus(ws):
    subprocess.run(["hyprctl", "dispatch", f'hl.dsp.focus({{workspace="{ws}"}})'], capture_output=True)
_focus("empty")
time.sleep(1.0)   # workspace switch animation

rc = 0
for panel in PANELS:
    a, b = capture(False, panel), capture(True, panel)
    if a is None or b is None:
        print(f"{panel:14s} could not detect popup (live={a is not None}, preview={b is not None})")
        rc = 1
        continue
    Image.fromarray(a.astype(np.uint8)).save(f"{OUT}/{panel}-live.png")
    Image.fromarray(b.astype(np.uint8)).save(f"{OUT}/{panel}-preview.png")
    if a.shape != b.shape:
        print(f"{panel:14s} SIZE differs: live {a.shape[1]}x{a.shape[0]} vs preview {b.shape[1]}x{b.shape[0]}")
        rc = 1
        continue
    d = np.abs(a - b).sum(axis=2) > 30
    vis = a.copy(); vis[d] = [255, 0, 0]
    Image.fromarray(vis.astype(np.uint8)).save(f"{OUT}/{panel}-diff.png")
    n = int(d.sum())
    print(f"{panel:14s} {a.shape[1]}x{a.shape[0]}  differing px: {n}")
    rc |= n > 0
_focus(_ws)
os.remove(f"{OUT}/_tmp.png")
sys.exit(rc)
