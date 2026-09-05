-- Input configuration
-- https://wiki.hypr.land/Configuring/Basics/Variables/#input

hl.config({
    input = {
        kb_layout   = "de",
        kb_variant  = "",
        kb_model    = "",
        kb_options  = "",
        kb_rules    = "",

        follow_mouse = 1,
        sensitivity  = 0,  -- -1.0 to 1.0, 0 = no modification

        touchpad = {
            natural_scroll = true,
        },
    },
})

-- Touchpad gestures: 3-finger horizontal swipe = workspace switch
hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})
