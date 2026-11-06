-- Window rules and workspace rules
-- https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

local home = os.getenv("HOME")
local scripts = home .. "/.config/hypr/scripts/special-workspaces/"

-- Floating windows sized as a fraction of their monitor. A size rule is only
-- evaluated when the window opens, so after a hotplug a window opened on the
-- 4K BenQ kept its size on the laptop screen (hanging off every edge).
-- relative_size() registers the window here and returns the rule's size; the
-- hook at the end re-applies it whenever the monitors change.
local refit = {}

-- class: exact class; title: optional Lua pattern
local function relative_size(fraction, class, title)
    table.insert(refit, { fraction = fraction, class = class, title = title })
    return { "monitor_w * " .. fraction, "monitor_h * " .. fraction }
end

-- ── GLOBAL ────────────────────────────────────────────
-- Suppress maximize events from all apps
hl.window_rule({
    name          = "suppress-maximize",
    match         = { class = ".*" },
    suppress_event = "maximize",
})

-- ── FLOATING TERMINAL ───────────────────────────────────
-- ghostty --class=dots.floating: short one-off commands launched by
-- quickshell (Apps.floatingTerminalCommand, e.g. installing bluez-tools)
hl.window_rule({
    match  = { class = "dots.floating" },
    float  = true,
    size   = relative_size(0.5, "dots.floating"),
    center = true,
})

-- ── BLUEMAN ───────────────────────────────────────────
hl.window_rule({
    match = { class = "blueman-manager" },
    float = true,
    size  = relative_size(0.8, "blueman-manager"),
})

-- ── PAVUCONTROL ───────────────────────────────────────
hl.window_rule({
    match = { class = "org.pulseaudio.pavucontrol" },
    float = true,
    size  = relative_size(0.6, "org.pulseaudio.pavucontrol"),
})

-- ── NM-CONNECTION-EDITOR ──────────────────────────────
hl.window_rule({
    match = { class = "nm-connection-editor" },
    float = true,
})

-- ── VIVALDI SETTINGS ──────────────────────────────────
hl.window_rule({
    match = { class = "vivaldi-stable", title = "(.*)Settings(.*)" },
    float = true,
    size  = relative_size(0.8, "vivaldi-stable", "Settings"),
})

-- ── VIVALDI BITWARDEN POPUP ───────────────────────────
-- The extension popup maps as "Vivaldi - Vivaldi" and only then becomes "Bitwarden - Vivaldi".
-- Float it as a tall, narrow window (once per window).
local bitwarden_done = {}
local function float_bitwarden(w)
    if not w or w.class ~= "vivaldi-stable" or w.title ~= "Bitwarden - Vivaldi" then return end
    if bitwarden_done[w.address] then return end
    bitwarden_done[w.address] = true
    hl.dispatch(hl.dsp.window.float({ action = "enable", window = w }))
    hl.dispatch(hl.dsp.window.resize({ x = 480, y = 800, window = w }))
    hl.dispatch(hl.dsp.window.center({ window = w }))
end
hl.on("window.open", float_bitwarden)
hl.on("window.title", float_bitwarden)
hl.on("window.close", function(w) if w then bitwarden_done[w.address] = nil end end)

-- ── VIVALDI SCREEN-SHARE BAR ("Freigabe beenden") ─────
-- Chromium's sharing indicator has no class; title e.g.
-- "meet.google.com hat ein Fenster geteilt." Pin it bottom-center.
hl.window_rule({
    match = { class = "^$", title = ".*(geteilt|frei)\\.?$" },
    float = true,
    move  = { "(monitor_w - window_w) / 2", "monitor_h - window_h - 20" },
})

hl.window_rule({
    match = { class = "md\\.obsidian\\.Obsidian" },  -- Obsidian >= 1.13 (was "obsidian")
    workspace = "name:obsidian"
})

-- ── IMPALA ────────────────────────────────────────────
hl.window_rule({
    match  = { title = "Impala" },
    float  = true,
    center = true,
    size   = { 800, 600 },
})

-- ── QALCULATE-GTK (Special workspace) ─────────────────
hl.window_rule({
    match     = { class = "qalculate-gtk" },
    workspace = "special:calculator",
})

-- ── SPOTIFY (Special workspace) ───────────────────────
hl.window_rule({
    match     = { initial_class = "Spotify" },
    float     = true,
    center    = true,
    size      = relative_size(0.8, "Spotify"),
    workspace = "special:spotify",
})

-- ── TELEGRAM (Special workspace) ──────────────────────
-- Don't let new messages steal focus (still marked urgent).
-- suppress_event replaces the global "maximize" one instead of adding to it,
-- so it is repeated here — Telegram restores its saved maximized state.
hl.window_rule({
    match             = { class = "org.telegram.desktop" },
    float             = true,
    center            = true,
    size              = relative_size(0.8, "org.telegram.desktop"),
    workspace         = "special:telegram",
    suppress_event    = "activatefocus maximize",
    -- suppress_event alone didn't stop it (Telegram still got focused on new
    -- messages); this dynamic rule does
    focus_on_activate = false,
})

-- ── SLACK (desktop app) + HUDDLES ────────────────────
-- Every Slack window has class "slack"; a huddle window opens titled
-- "Slack - Huddle Preview" (rules match the title at open) and starts fullscreen
hl.window_rule({
    match     = { class = "slack", title = "negative:.*[Hh]uddle.*" },
    workspace = "name:slack",
})
hl.window_rule({
    match      = { class = "slack", title = ".*[Hh]uddle.*" },
    workspace  = "name:huddle",
    fullscreen = true,
})

-- ── TEAMS (teams-for-linux) ───────────────────────────
hl.window_rule({
    match     = { class = "teams-for-linux" },
    workspace = "name:teams",
})

-- ── SMART GAPS (No gaps when only one window) ─────────
hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })

hl.window_rule({
    match       = { float = false, workspace = "w[tv1]" },
    border_size = 0,
    rounding    = 0,
})
hl.window_rule({
    match       = { float = false, workspace = "f[1]" },
    border_size = 0,
    rounding    = 0,
})

-- ── GAMES: no idle while a Steam game is fullscreen ────
-- Gamepad input bypasses the compositor, so controller-only play looks idle.
-- Games run as steam_app_<id> (XWayland/Proton) or steam.app.<id> (native
-- Wayland Proton) — not "steam". The quickshell IdleService respects this
-- Wayland inhibitor (respectInhibitors).
hl.window_rule({
    match        = { class = "steam[._]app[._].*" },
    idle_inhibit = "fullscreen",
})

-- ── REFIT AFTER MONITOR CHANGES ───────────────────────
-- Re-apply relative_size() to the registered floating windows on the monitor
-- each one is on now. Monitor width/height are physical pixels, the rules'
-- monitor_w/h are logical → divide by scale. Runs after workspaces.lua has
-- moved the workspaces around (500 + 200 ms). Fullscreen/maximized windows are
-- left alone; a manual resize is lost on the next monitor change.
local function refit_windows()
    for _, w in ipairs(hl.get_windows({ floating = true })) do
        local m = w.monitor
        if m and w.fullscreen == 0 then
            for _, r in ipairs(refit) do
                if w.class == r.class and (not r.title or w.title:find(r.title)) then
                    local width  = math.floor(m.width  / m.scale * r.fraction + 0.5)
                    local height = math.floor(m.height / m.scale * r.fraction + 0.5)
                    hl.dispatch(hl.dsp.window.resize({ x = width, y = height, window = w }))
                    hl.dispatch(hl.dsp.window.center({ window = w }))
                    break
                end
            end
        end
    end
end

local function refit_soon()
    hl.timer(refit_windows, { timeout = 1000, type = "oneshot" })
end
hl.on("monitor.added", refit_soon)
hl.on("monitor.removed", refit_soon)
hl.on("monitor.layout_changed", refit_soon)
