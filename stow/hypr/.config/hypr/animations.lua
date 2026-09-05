-- Animation curves and settings
-- https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/

hl.config({
    animations = {
        enabled = true,
    },
})

-- Custom bezier curve
hl.curve("myBezier", {
    type   = "bezier",
    points = { { 0.05, 0.9 }, { 0.1, 1.05 } },
})

-- Default curve (used as fallback)
hl.curve("default", {
    type   = "bezier",
    points = { { 0.25, 0.1 }, { 0.25, 1.0 } },
})

-- Window animations
hl.animation({ leaf = "windows",    enabled = true, speed = 7,  bezier = "myBezier" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 7,  bezier = "default",  style = "popin 80%" })
hl.animation({ leaf = "border",     enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "fade",       enabled = true, speed = 7,  bezier = "default" })

-- Disable workspace animations
hl.animation({ leaf = "workspaces", enabled = false })
