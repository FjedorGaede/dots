#!/usr/bin/env bash
# Brightness wrapper with a minimum floor so the screen never goes fully dark
STEP=5%
MIN=5%

case "$1" in
    up)   brightnessctl -q set "$STEP+" ;;
    down) brightnessctl -q -n"$MIN" set "$STEP-" ;;
    *)    echo "usage: $0 up|down" >&2; exit 1 ;;
esac
