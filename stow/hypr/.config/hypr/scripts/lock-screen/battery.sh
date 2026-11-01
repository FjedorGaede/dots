#!/bin/bash

# First battery, whatever its number (BAT0 on some laptops, BAT1 on others);
# no battery (desktop) → print nothing
battery=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n1)
[ -n "$battery" ] || exit 0

# Get the current battery percentage
battery_percentage=$(cat "$battery/capacity")

# Get the battery status (Charging or Discharging)
battery_status=$(cat "$battery/status")

# Define the battery icons for each 10% segment
battery_icons=("󰂃" "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰁹")

# Define the charging icon
charging_icon="󰂄"
full_icon="󰂅"

# Calculate the index for the icon array
# cap the index: at exactly 100% the raw index would be 10 (out of bounds)
icon_index=$((battery_percentage / 10))
[ "$icon_index" -gt 9 ] && icon_index=9

# Get the corresponding icon
battery_icon=${battery_icons[icon_index]}

# Check if the battery is charging
if [ "$battery_status" = "Charging" ]; then
	battery_icon="$charging_icon"
fi

# Check if the battery is full
if [ "$battery_status" = "Full" ]; then
	battery_icon="$full_icon"
fi

# Output the battery percentage and icon
echo "$battery_percentage% $battery_icon"
