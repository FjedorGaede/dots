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

-- ── VIVALDI BITWARDEN ─────────────────────────────────
hl.window_rule({
    match = { class = "vivaldi-stable", title = "(.*)Bitwarden(.*)" },
    float = true,
    size  = { "monitor_w * 0.8", "monitor_h * 0.8" },
})

-- ── VIVALDI GOOGLE LOGIN ──────────────────────────────
hl.window_rule({
    match = { class = "vivaldi-stable", title = "^(Anmelden.*)$" },
    float = true,
    size  = { "monitor_w * 0.8", "monitor_h * 0.8" },
})

hl.window_rule({
    match = { class = "obsidian" },
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

-- ── BITWARDEN (Special workspace) ─────────────────────
hl.window_rule({
    match     = { initial_class = "Bitwarden" },
    float     = true,
    center    = true,
    size      = { "monitor_w * 0.9", "monitor_h * 0.9" },
    workspace = "special:bitwarden",
})

-- ── TELEGRAM (Special workspace) ──────────────────────
hl.window_rule({
    match     = { class = "org.telegram.desktop" },
    float     = true,
    center    = true,
    size      = { "monitor_w * 0.9", "monitor_h * 0.9" },
    workspace = "special:telegram",
})

-- ── ROFI ──────────────────────────────────────────────
hl.window_rule({
    match  = { class = "Rofi" },
    no_blur = true,
})

-- ── AGS OVERLAY (Blur background) ─────────────────────
hl.layer_rule({
    match = { namespace = agsWindowName },
    blur  = true,
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
