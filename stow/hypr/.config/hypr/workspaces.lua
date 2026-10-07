-- Main-monitor workspace layout
--
-- One "main" monitor gets workspaces 1-9 plus the named ones (slack, huddle,
-- obsidian, ...) — Super+N always lands there and never touches the other
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
    for _, name in ipairs({ "slack", "huddle", "obsidian" }) do
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
            local target = own[ws.id] or main
            if ws.monitor.name ~= target.name then
                local selector = ws.id > 0 and tostring(ws.id) or "name:" .. ws.name
                hl.dispatch(hl.dsp.workspace.move({ workspace = selector, monitor = target.name }))
            end
        end
    end

    -- After a hotplug the main monitor may show another screen's workspace
    -- (10 after unplugging) or one Hyprland made up for it (11, 12, ...):
    -- show the lowest of 1-9 instead
    local shown = main.active_workspace
    if not shown or shown.id > 9 then
        local lowest
        for _, ws in ipairs(hl.get_workspaces()) do
            if ws.id >= 1 and ws.id <= 9 and (not lowest or ws.id < lowest) then lowest = ws.id end
        end
        if lowest then main:set_workspace({ workspace = lowest }) end
    end
end

-- Monitors may not exist yet while the config loads at startup
hl.on("hyprland.start", apply)
hl.timer(apply, { timeout = 50, type = "oneshot" })

-- Hotplug: give the new monitor a moment to get its first workspace
local function apply_soon() hl.timer(apply, { timeout = 500, type = "oneshot" }) end
hl.on("monitor.added", apply_soon)
hl.on("monitor.removed", apply_soon)
