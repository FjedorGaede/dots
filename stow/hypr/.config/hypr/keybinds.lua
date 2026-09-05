-- Keybindings
-- https://wiki.hypr.land/Configuring/Basics/Binds/

-- Reusable bind helpers
local function bindMain(key, handler, opts)
    hl.bind(mainMod .. " + " .. key, handler, opts)
end

local function bindMainShift(key, handler, opts)
    hl.bind(mainModShift .. " + " .. key, handler, opts)
end

-- ── GENERAL ────────────────────────────────────────────
bindMain("RETURN",  hl.dsp.exec_cmd(terminal))
bindMain("B",       hl.dsp.exec_cmd(browser))
bindMain("Q",       hl.dsp.window.close())
bindMainShift("M",  hl.dsp.exit())
bindMain("E",       hl.dsp.exec_cmd(fileManager))
bindMain("V",       hl.dsp.window.float({ action = "toggle" }))
bindMain("D",       hl.dsp.exec_cmd(menu))
bindMain("G",       hl.dsp.exec_cmd(smartSearch))
bindMain("F",       hl.dsp.window.fullscreen({ mode = 1 }))
bindMainShift("L",  hl.dsp.exec_cmd("hyprlock"))
bindMainShift("Q",  hl.dsp.exec_cmd("wlogout"))
bindMainShift("W",  hl.dsp.exec_cmd("pkill waybar && waybar"))
bindMainShift("N",  hl.dsp.exec_cmd("qs ipc call notifications toggle"))

-- AGS Overlay Window
bindMainShift("H",  hl.dsp.exec_cmd("astal -t " .. agsWindowName))

-- ── LID CLOSE ─────────────────────────────────────────
hl.bind("switch:Lid Switch", hl.dsp.exec_cmd("systemctl suspend"), { locked = true })

-- ── SCREENSHOTS ───────────────────────────────────────
bindMain("PRINT",       hl.dsp.exec_cmd("hyprshot -m window --clipboard-only"))
hl.bind("PRINT",        hl.dsp.exec_cmd("hyprshot -m output --clipboard-only"))
hl.bind("SHIFT + PRINT", hl.dsp.exec_cmd("hyprshot -m region --clipboard-only"))

-- ── FOCUS (vim-style) ─────────────────────────────────
bindMain("H", hl.dsp.focus({ direction = "left" }))
bindMain("L", hl.dsp.focus({ direction = "right" }))
bindMain("K", hl.dsp.focus({ direction = "up" }))
bindMain("J", hl.dsp.focus({ direction = "down" }))

-- ── WORKSPACES ────────────────────────────────────────
for i = 1, 10 do
    local key = i % 10  -- workspace 10 maps to key 0
    bindMain(key,      hl.dsp.focus({ workspace = i }))
    bindMainShift(key, hl.dsp.window.move({ workspace = i }))
end

-- ── MOUSE ─────────────────────────────────────────────
bindMain("mouse:272", hl.dsp.window.drag(),   { mouse = true })  -- move window
bindMain("mouse:273", hl.dsp.window.resize(), { mouse = true })  -- resize window

-- ── AUDIO ─────────────────────────────────────────────
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),   { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),         { locked = true, repeating = true })

-- ── BRIGHTNESS ────────────────────────────────────────
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl set +10%"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 10%-"), { locked = true, repeating = true })

-- ── SPECIAL WORKSPACES (SCRATCHPADS) ──────────────────
bindMain("C", hl.dsp.exec_cmd("pgrep qalculate-gtk && hyprctl dispatch togglespecialworkspace calculator || qalculate-gtk &"))
bindMain("S", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/special-workspaces/spotify.sh"))
bindMain("T", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/special-workspaces/telegram.sh"))
bindMain("O", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/special-workspaces/obsidian.sh"))

-- ── SUBMAP: RESIZE ────────────────────────────────────
bindMain("R", hl.dsp.submap("resize"))

hl.define_submap("resize", function()
    hl.bind("L",      hl.dsp.window.resize({ x =  10, y =   0, relative = true }), { repeating = true })
    hl.bind("H",      hl.dsp.window.resize({ x = -10, y =   0, relative = true }), { repeating = true })
    hl.bind("K",      hl.dsp.window.resize({ x =   0, y = -10, relative = true }), { repeating = true })
    hl.bind("J",      hl.dsp.window.resize({ x =   0, y =  10, relative = true }), { repeating = true })
    hl.bind("ESCAPE", hl.dsp.submap("reset"))
end)
