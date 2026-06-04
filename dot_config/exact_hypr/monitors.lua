-- Monitor configuration
-- https://wiki.hypr.land/Configuring/Basics/Monitors/

-- Main laptop display: BOE 16" 2560x1600 @ 60Hz, scale 1.333
hl.monitor({
    output   = "desc:BOE 0x0AF0",
    mode     = "2560x1600@240",
    position = "auto",
    scale    = 1.333,
})

-- External LG WQHD monitor
hl.monitor({
    output   = "desc:LG Electronics LG HDR WQHD 102NTUW9D902",
    mode     = "preferred",
    position = "auto",
    scale    = 1.25,
})

-- Default fallback for any other monitor
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})
