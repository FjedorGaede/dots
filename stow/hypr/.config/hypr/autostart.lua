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
end)
