#!/usr/bin/env python3
"""Pixel-compare the live bar (y=0) with the preview bar (y=30).

Dev tool for the refactor (docs/REFACTOR.md §11). The bar window is
transparent between pills, so the wallpaper differs between the two strips;
only the opaque pill areas are compared.

Usage: bar-diff.py [outdir]    (default /tmp/qs-bar-diff)
Exit 0 = identical pills, 1 = differences (see diff.png).
"""
import json, os, subprocess, sys
import numpy as np
from PIL import Image

out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/qs-bar-diff"
os.makedirs(out, exist_ok=True)

def grab(y, name):
    p = f"{out}/{name}.png"
    subprocess.run(["grim", "-g", f"0,{y} 1920x30", p], check=True)
    return np.asarray(Image.open(p).convert("RGB")).astype(int)

live, prev = grab(0, "live"), grab(30, "preview")
h, w, _ = live.shape

bg_hex = json.load(open(os.path.expanduser("~/.cache/wal/colors.json")))["special"]["background"]
bg = np.array([int(bg_hex[i:i + 2], 16) for i in (1, 3, 5)])

def pill_cols(img):
    # a column belongs to a pill if a row just inside the pill's top edge is bg
    probe = img[int(h * 0.2)]
    return (np.abs(probe - bg).sum(axis=1) < 12)

ml, mp = pill_cols(live), pill_cols(prev)
geom_diff = int((ml != mp).sum())

rows = slice(int(h * 0.2), int(h * 0.8))
mask = ml & mp
delta = np.abs(live[rows][:, mask] - prev[rows][:, mask]).sum(axis=2)
px_diff = int((delta > 30).sum())

vis = live.copy()
full = np.zeros((h, w), bool)
sub = np.zeros((rows.stop - rows.start, w), bool)
sub[:, mask] = delta > 30
full[rows] = sub
full[:, ml != mp] = True
vis[full] = [255, 0, 0]
Image.fromarray(vis.astype(np.uint8)).save(f"{out}/diff.png")

print(f"pill-geometry column mismatches: {geom_diff}")
print(f"differing pixels inside pills:   {px_diff}")
print(f"images: {out}/live.png  {out}/preview.png  {out}/diff.png")
sys.exit(0 if geom_diff == 0 and px_diff == 0 else 1)
