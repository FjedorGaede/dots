-- Appearance: general settings, decoration, layout, misc
-- https://wiki.hypr.land/Configuring/Basics/Variables/

hl.config({

    -- General
    general = {
        gaps_in    = 2,
        gaps_out   = 5,
        border_size = 2,

        col = {
            active_border   = color5,
            inactive_border = color8,
        },

        resize_on_border = true,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    -- Decoration
    decoration = {
        rounding = 7,

        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled      = true,
            color        = "rgba(1a1a1aee)",
            range        = 4,
            render_power = 3,
        },

        blur = {
            enabled           = true,
            size              = 3,
            passes            = 1,
            vibrancy          = 0.3,
            vibrancy_darkness = 0.3,
            contrast          = 1.3,
        },
    },

    -- Dwindle layout
    dwindle = {
        preserve_split = true,
    },

    -- Misc
    misc = {
        force_default_wallpaper = -1,  -- Disable anime wallpapers
        disable_hyprland_logo   = true,
        focus_on_activate       = true,
    },

    -- XWayland
    xwayland = {
        force_zero_scaling = true,
    },

})
