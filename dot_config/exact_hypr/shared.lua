-- Shared variables: colors, fonts, wallpaper
-- Parses pywal colors dynamically so theme changes still work

local shared = {}

-- Parse pywal colors-hyprland.conf into a Lua table
-- Format: $colorName = rgba(r,g,b,a) or rgb(r,g,b)
local function parse_pywal_colors(path)
    local colors = {}
    local file = io.open(path, "r")
    if not file then
        -- Fallback: use hardcoded colors if pywal file is missing
        colors.color0  = "rgba(0,0,0,1.0)"
        colors.color1  = "rgba(255,85,85,1.0)"
        colors.color2  = "rgba(80,250,123,1.0)"
        colors.color3  = "rgba(241,250,140,1.0)"
        colors.color4  = "rgba(189,147,249,1.0)"
        colors.color5  = "rgba(255,121,198,1.0)"
        colors.color6  = "rgba(139,233,253,1.0)"
        colors.color7  = "rgba(191,191,191,1.0)"
        colors.color8  = "rgba(77,77,77,1.0)"
        colors.color9  = "rgba(255,110,103,1.0)"
        colors.color10 = "rgba(90,247,142,1.0)"
        colors.color11 = "rgba(244,249,157,1.0)"
        colors.color12 = "rgba(202,169,250,1.0)"
        colors.color13 = "rgba(255,146,208,1.0)"
        colors.color14 = "rgba(154,237,254,1.0)"
        colors.color15 = "rgba(230,230,230,1.0)"
        colors.highlight = "rgba(255,121,198,1.0)"
        colors.subdued = "rgba(77,77,77,1.0)"
        colors.fontcolor_white = "rgba(235,235,235,1.0)"
        colors.foreground = "rgba(248,248,242,1.0)"
        colors.background = "rgba(40,42,54,1.0)"
        return colors
    end

    for line in file:lines() do
        -- Match: $name = rgba(r,g,b,a) or rgb(r,g,b)
        local name, value = line:match("^%$([%w_]+)%s*=%s*(.+)$")
        if name and value then
            colors[name] = value
        end
    end
    file:close()
    return colors
end

-- Load pywal colors
local wal_colors = parse_pywal_colors(os.getenv("HOME") .. "/.cache/wal/colors-hyprland.conf")

-- Export colors globally so other modules can use them
for k, v in pairs(wal_colors) do
    _G[k] = v
end

-- Fonts
mainFont = "JetBrainsMono NFP"
mainFontSemiBold = "JetBrainsMono NFP SemiBold"

-- Wallpaper
wallpaper1 = os.getenv("HOME") .. "/.config/hypr/wallpapers/DSD-Universe.png"

-- Programs
terminal     = "ghostty"
fileManager  = "nautilus"
browser      = "vivaldi-stable"
menu         = "walker"
smartSearch  = 'rofi -show smartsearch -theme-str \'entry { placeholder: "Smart Search..."; }\''

-- Modifier keys
mainMod      = "SUPER"
mainModShift = "SUPER + SHIFT"

-- Scratchpad / special workspace apps
agsWindowName = "HomeWindow"

return shared