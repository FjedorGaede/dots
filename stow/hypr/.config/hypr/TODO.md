# Hyprland TODO

## Workspace 10 invisible on secondary screen (stuck workspace offset)

**Seen:** 2026-10-07. Windows on workspace 10 (laptop screen eDP-1, BenQ DP-2 was
main) were mapped/visible per `hyprctl clients` but not drawn. A window moved
there briefly showed up shifted ~one screen width to the right (x ≈ 1920 = where
DP-2 starts). `hyprctl monitors` showed `solitaryBlockedBy: ... workspace offset`
on eDP-1.

**Workaround that fixed it:** switch eDP-1 to an empty workspace and back:
```
hyprctl dispatch 'hl.dsp.focus({ monitor = "eDP-1" })'
hyprctl dispatch 'hl.dsp.focus({ workspace = 11 })'
hyprctl dispatch 'hl.dsp.focus({ workspace = 10 })'
```
Afterwards `workspace offset` was gone and content rendered.

**Suspected cause (unproven):** on hotplug, workspaces move between monitors
twice — once by Hyprland, then by `apply()` in `workspaces.lua` 500 ms later.
With workspace animations disabled (`animations.lua`), the render offset from a
monitor move apparently isn't always reset.

**Plan (agreed, not done yet):**
1. Reproduce: unplug + replug BenQ, send a window to workspace 10, check if it's
   invisible / `workspace offset` is back.
2. If it reproduces: at the end of `apply()` in `workspaces.lua`, bounce each
   non-main monitor to an empty temp workspace and back to its own (10, 11, ...)
   to reset the offset. Cost: brief flicker on hotplug.
