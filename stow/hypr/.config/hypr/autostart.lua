-- Autostart applications (run once when Hyprland starts)
-- https://wiki.hypr.land/Configuring/Basics/Autostart/

hl.on("hyprland.start", function()
    hl.exec_cmd("hyprpaper")
    -- idle (dim/lock/screen-off/suspend) is handled by quickshell: services/IdleService.qml
    -- only on machines with the tuxedo-extras category installed
    hl.exec_cmd("command -v tuxedo-control-center >/dev/null && tuxedo-control-center")
    hl.exec_cmd("qs")
    hl.exec_cmd("elephant")
    hl.exec_cmd("walker --gapplication-service")
    -- pairing agent: quickshell's bluetooth panel can pair but can't answer
    -- passkey confirmations (no BlueZ agent API) — same approach as omarchy 4.x
    hl.exec_cmd("bt-agent -c NoInputNoOutput")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")

    -- startup layout: browser on 1, terminal running herdr on 2
    -- (exec_cmd rules match by PID, so these must open their window directly)
    hl.exec_cmd(browser, { workspace = "1 silent" })
    hl.exec_cmd(terminal .. " -e " .. os.getenv("HOME") .. "/.local/bin/herdr", { workspace = "2 silent" })
end)
