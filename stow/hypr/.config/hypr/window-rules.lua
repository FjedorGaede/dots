-- Window rules and workspace rules
-- https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

local home = os.getenv("HOME")
local scripts = home .. "/.config/hypr/scripts/special-workspaces/"

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
    size   = { "monitor_w * 0.5", "monitor_h * 0.5" },
    center = true,
})

-- ── BLUEMAN ───────────────────────────────────────────
hl.window_rule({
    match = { class = "blueman-manager" },
    float = true,
    size  = { "monitor_w * 0.8", "monitor_h * 0.8" },
})

-- ── PAVUCONTROL ───────────────────────────────────────
hl.window_rule({
    match = { class = "org.pulseaudio.pavucontrol" },
    float = true,
    size  = { "monitor_w * 0.6", "monitor_h * 0.6" },
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
    size  = { "monitor_w * 0.8", "monitor_h * 0.8" },
})

-- ── VIVALDI BITWARDEN POPUP ───────────────────────────
-- Same late-title problem as the Google login below: the extension popup
-- maps as "Vivaldi - Vivaldi" and only then becomes "Bitwarden - Vivaldi".
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

-- ── VIVALDI GOOGLE LOGIN ──────────────────────────────
-- The popup maps as "Vivaldi - Vivaldi" and only later gets its
-- "Anmelden – Google Konten" title, so a static rule never matches.
-- Float/size/center it on title change instead (once per window).
local google_login_done = {}
local function float_google_login(w)
    if not w or w.class ~= "vivaldi-stable" or not w.title:match("^Anmelden") then return end
    if google_login_done[w.address] then return end
    google_login_done[w.address] = true
    hl.dispatch(hl.dsp.window.float({ action = "enable", window = w }))
    hl.dispatch(hl.dsp.window.resize({ x = 600, y = 760, window = w }))
    hl.dispatch(hl.dsp.window.center({ window = w }))
end
hl.on("window.open", float_google_login)
hl.on("window.title", float_google_login)
hl.on("window.close", function(w) if w then google_login_done[w.address] = nil end end)

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
    size      = { "monitor_w * 0.9", "monitor_h * 0.9" },
    workspace = "special:spotify",
})

-- ── TELEGRAM (Special workspace) ──────────────────────
-- Don't let new messages steal focus (still marked urgent)
hl.window_rule({
    match          = { class = "org.telegram.desktop" },
    float          = true,
    center         = true,
    size           = { "monitor_w * 0.9", "monitor_h * 0.9" },
    workspace      = "special:telegram",
    suppress_event = "activatefocus",
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
