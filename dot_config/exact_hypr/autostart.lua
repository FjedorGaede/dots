-- Autostart applications (run once when Hyprland starts)
-- https://wiki.hypr.land/Configuring/Basics/Autostart/

hl.on("hyprland.start", function()
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("tuxedo-control-center")
    hl.exec_cmd("qs")
    hl.exec_cmd("swaync")
    hl.exec_cmd("elephant")
    hl.exec_cmd("walker --gapplication-service")
end)
