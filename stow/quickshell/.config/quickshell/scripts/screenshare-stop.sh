#!/bin/bash
# Stop every screen share (bar indicator, services/ScreenShareService.qml).
#
# Apps only end a share when THEY close the portal session — xdph never emits
# Session.Closed, and xdg-desktop-portal lets only the owner close a session.
# So for Chromium (Vivaldi/Meet) we press its own "Stop sharing" button: the
# classless "… hat ein Fenster geteilt." bar has no default button → focus it,
# Tab onto the first button ("Freigabe beenden"), Return.
# Everything else (Slack, OBS, …): destroy the xdph PipeWire node — no more
# frames leave, but the app still thinks it is sharing (frozen last frame).
set -u

prev=$(hyprctl activewindow -j | jq -r '.address // empty')

bars=$(hyprctl clients -j | jq -r '.[]
    | select(.class == "" and (.title | test("(geteilt|frei|sharing .*)\\.?$")))
    | .address')

for a in $bars; do
    hyprctl dispatch "hl.dsp.focus({window=\"address:$a\"})" >/dev/null
    sleep 0.3
    hyprctl dispatch "hl.dsp.send_shortcut({mods=\"\", key=\"Tab\", window=\"address:$a\"})" >/dev/null
    sleep 0.2
    hyprctl dispatch "hl.dsp.send_shortcut({mods=\"\", key=\"Return\", window=\"address:$a\"})" >/dev/null
done

xdph_nodes() {
    pw-dump 2>/dev/null | jq -r '.[]
        | select(.type == "PipeWire:Interface:Node" and .info.props["node.name"] == "xdg-desktop-portal-hyprland")
        | .id'
}

# Give Chromium a moment to close its session, then cut whatever is left
[ -n "$bars" ] && sleep 1.5
for id in $(xdph_nodes); do
    pw-cli destroy "$id" >/dev/null 2>&1
done

# Focusing the bar stole focus — hand it back
if [ -n "$prev" ] && hyprctl clients -j | jq -e --arg a "$prev" 'any(.[]; .address == $a)' >/dev/null; then
    hyprctl dispatch "hl.dsp.focus({window=\"address:$prev\"})" >/dev/null
fi
