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
bindMain("F",       hl.dsp.window.fullscreen({ mode = 1 }))
bindMainShift("L",  hl.dsp.exec_cmd("hyprlock"))
-- (wlogout / waybar are dropped: Super+Shift+Q = quickshell home menu with the
--  lock/suspend/logout/reboot/shutdown buttons, Super+Shift+W = restart the bar)
bindMainShift("Q",  hl.dsp.exec_cmd("qs ipc call home toggle"))
-- `qs kill` only kills ONE instance → a leftover one stacked a second bar
-- below the first; kill them all (process name is qs or quickshell)
bindMainShift("W",  hl.dsp.exec_cmd("pkill -x qs; pkill -x quickshell; sleep 0.3; qs -d"))
bindMainShift("N",  hl.dsp.exec_cmd("qs ipc call notifications toggle"))

-- quickshell home menu (services/PanelService.qml, IPC target "home");
-- plain Super+H stays "focus left"
bindMainShift("H",  hl.dsp.exec_cmd("qs ipc call home toggle"))

-- ── LID CLOSE ─────────────────────────────────────────
hl.bind("switch:Lid Switch", hl.dsp.exec_cmd("systemctl suspend"), { locked = true })

-- ── SCREENSHOTS ───────────────────────────────────────
bindMain("PRINT",       hl.dsp.exec_cmd("hyprshot -m window --clipboard-only"))
hl.bind("PRINT",        hl.dsp.exec_cmd("hyprshot -m output --clipboard-only"))
hl.bind("SHIFT + PRINT", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/screenshot-region.sh"))
bindMainShift("S",  hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/screenshot-region.sh"))

-- ── SCREEN RECORDING ──────────────────────────────────
-- quickshell recorder (services/RecorderService.qml, IPC target "recording"):
-- menu when idle, stop while recording (pause/resume: buttons in the bar)
bindMain("R",  hl.dsp.exec_cmd("qs ipc call recording toggle"))
-- straight to the region drag, no menu (audio as last set in the menu)
bindMainShift("R",  hl.dsp.exec_cmd("qs ipc call recording start region"))

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
-- wrapper adds a floor so brightness never reaches 0 (see scripts/brightness.sh)
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("~/.config/hypr/scripts/brightness.sh up"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("~/.config/hypr/scripts/brightness.sh down"), { locked = true, repeating = true })

-- ── SPECIAL WORKSPACES (SCRATCHPADS) ──────────────────
bindMain("C", hl.dsp.exec_cmd("pgrep qalculate-gtk && hyprctl dispatch togglespecialworkspace calculator || qalculate-gtk &"))
bindMain("S", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/special-workspaces/spotify.sh"))
bindMain("T", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/special-workspaces/telegram.sh"))
bindMain("O", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/special-workspaces/obsidian.sh"))
