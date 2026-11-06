-- Main-monitor workspace layout
--
-- One "main" monitor gets workspaces 1-9 plus the named ones (slack, huddle,
-- teams, obsidian, ...) — Super+N always lands there and never touches the other
-- screens. Every other monitor gets one workspace of its own (10, 11, ...,
-- left to right), shown permanently; fill it by hand (Super+Shift+0 → 10).
--
-- Main = the monitor picked in quickshell's Displays menu (its description is
-- stored in the machine-local state file below), else the laptop panel
-- (eDP-*), else the first monitor. Re-applied on monitor hotplug and on every
-- config reload — the Displays menu writes the file and reloads.

local state_file = (os.getenv("XDG_STATE_HOME") or os.getenv("HOME") .. "/.local/state")
    .. "/hypr/main-monitor"

local function main_description()
    local f = io.open(state_file)
    if not f then return nil end
    local desc = f:read("l")
    f:close()
    if desc == "" then return nil end
    return desc
end

local function main_monitor(monitors)
    local desc = main_description()
    for _, m in ipairs(monitors) do
        if desc and m.description == desc then return m end
    end
    for _, m in ipairs(monitors) do
        if m.name:match("^eDP") then return m end
    end
    return monitors[1]
end

-- Rules added by the last apply(); disabled before new ones are added
local rules = {}

local function rule(spec)
    table.insert(rules, hl.workspace_rule(spec))
end

local function apply()
    local monitors = hl.get_monitors()
    if #monitors == 0 then return end

    local main = main_monitor(monitors)
    local others = {}
    for _, m in ipairs(monitors) do
        if m.name ~= main.name then table.insert(others, m) end
    end
    table.sort(others, function(a, b) return a.position.x < b.position.x end)

    for _, r in ipairs(rules) do r:set_enabled(false) end
    rules = {}

    -- Workspace rules decide where a workspace is CREATED
    for i = 1, 9 do
        rule({ workspace = tostring(i), monitor = main.name, default = (i == 1) })
    end
    for _, name in ipairs({ "slack", "huddle", "teams", "obsidian" }) do
        rule({ workspace = "name:" .. name, monitor = main.name })
    end
    local own = {}  -- workspace id → monitor, for the other screens
    for i, m in ipairs(others) do
        local id = 9 + i
        own[id] = m
        -- persistent: exists (and is shown) even while empty
        rule({ workspace = tostring(id), monitor = m.name, default = true, persistent = true })
        if not (m.active_workspace and m.active_workspace.id == id) then
            m:set_workspace({ workspace = id })
        end
    end

    -- ...existing workspaces are moved to where they belong
    for _, ws in ipairs(hl.get_workspaces()) do
        if not ws.special and ws.monitor then
            local target = (ws.id and own[ws.id]) or main
            if ws.monitor.name ~= target.name then
                local selector = ws.id and ws.id > 0 and tostring(ws.id) or "name:" .. ws.name
                hl.dispatch(hl.dsp.workspace.move({ workspace = selector, monitor = target.name }))
            end
        end
    end

    -- After a hotplug the main monitor may show another screen's workspace
    -- (10 after unplugging) or one Hyprland made up for it (11, 12, ...):
    -- show the lowest of 1-9 instead
    local shown = main.active_workspace
    if not shown or (shown.id and shown.id > 9) then
        local lowest
        for _, ws in ipairs(hl.get_workspaces()) do
            if ws.id and ws.id >= 1 and ws.id <= 9 and (not lowest or ws.id < lowest) then lowest = ws.id end
        end
        if lowest then main:set_workspace({ workspace = lowest }) end
    end
end

-- Monitors may not exist yet while the config loads at startup
hl.on("hyprland.start", apply)
hl.timer(apply, { timeout = 50, type = "oneshot" })

-- After a hotplug, moving workspaces between monitors can leave a stale render
-- offset on a secondary screen (solitaryBlockedBy: "workspace offset"): its
-- windows exist but are drawn ~one screen width off. Switching that screen to an
-- empty temp workspace and back resets it (brief flicker).
local BOUNCE_WS = 99

local function bounce_others()
    local monitors = hl.get_monitors()
    if #monitors < 2 then return end
    local main = main_monitor(monitors)
    for _, m in ipairs(monitors) do
        local ws = m.active_workspace
        if m.name ~= main.name and ws and ws.id and ws.id > 9 then
            m:set_workspace({ workspace = BOUNCE_WS })
            m:set_workspace({ workspace = ws.id })
        end
    end
end

-- Hotplug: give the new monitor a moment to get its first workspace, then let
-- the workspace moves settle before bouncing
local hotplugging = false  -- fix_new_workspaces() stays out of the way meanwhile

local function apply_soon()
    hotplugging = true
    hl.timer(function()
        apply()
        hotplugging = false
        hl.timer(bounce_others, { timeout = 200, type = "oneshot" })
    end, { timeout = 500, type = "oneshot" })
end
hl.on("monitor.added", apply_soon)
hl.on("monitor.removed", apply_soon)

-- Workspace rules are ignored when a workspace is created by moving a window
-- into it (Super+Shift+N) or by a window rule (obsidian, slack, ...): it then
-- appears on whatever monitor had focus. Move such workspaces to the main
-- monitor right after they appear. Only 1-9 and the named ones are touched —
-- the other screens' own workspaces (10, 11, ...) are left to apply().
local MAIN_NAMES = { slack = true, huddle = true, teams = true, obsidian = true }

local function belongs_on_main(ws)
    if ws.special then return false end
    if ws.id and ws.id >= 1 and ws.id <= 9 then return true end
    return MAIN_NAMES[ws.name] == true
end

local function fix_new_workspaces()
    if hotplugging then return end
    local monitors = hl.get_monitors()
    if #monitors < 2 then return end
    local main = main_monitor(monitors)

    local others = {}
    for _, m in ipairs(monitors) do
        if m.name ~= main.name then table.insert(others, m) end
    end
    table.sort(others, function(a, b) return a.position.x < b.position.x end)
    local own = {}  -- monitor name → its own workspace id
    for i, m in ipairs(others) do own[m.name] = 9 + i end

    for _, ws in ipairs(hl.get_workspaces()) do
        local from = ws.monitor
        if from and from.name ~= main.name and belongs_on_main(ws) then
            -- If it's shown there, show that screen's own workspace first, so
            -- Hyprland doesn't make up a new one (which could be 1-9 again)
            local shown = from.active_workspace
            if shown and shown.name == ws.name and own[from.name] then
                from:set_workspace({ workspace = own[from.name] })
            end
            local selector = ws.id and ws.id > 0 and tostring(ws.id) or "name:" .. ws.name
            hl.dispatch(hl.dsp.workspace.move({ workspace = selector, monitor = main.name }))
            main:set_workspace({ workspace = selector })
        end
    end
end

-- Deferred: don't move a workspace while Hyprland is still creating it
hl.on("workspace.created", function()
    hl.timer(fix_new_workspaces, { timeout = 50, type = "oneshot" })
end)
