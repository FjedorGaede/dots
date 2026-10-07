-- Hyprland Lua Configuration
-- Migrated from hyprlang to Lua for Hyprland >= 0.55
-- https://wiki.hypr.land/Configuring/Start/

-- The Lua state survives `hyprctl reload`, and require() caches modules in
-- package.loaded — drop the cache first so edits actually get re-read.
local function load(name)
    package.loaded[name] = nil
    require(name)
end

load("shared")        -- Colors, fonts, wallpaper, variables
load("monitors")      -- Monitor setup
load("appearance")    -- General, decoration, dwindle, misc
load("animations")    -- Curves and animation settings
load("input")         -- Keyboard, mouse, touchpad, gestures
load("autostart")     -- Startup applications
load("keybinds")      -- Keybindings and submaps
load("window-rules")  -- Window rules and workspace rules
load("workspaces")    -- Main monitor gets 1-9, other monitors one workspace each
