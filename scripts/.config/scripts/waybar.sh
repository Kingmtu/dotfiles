#!/bin/bash
# Toggle Waybar visibility for Niri window manager
# Checks if Waybar is running; starts it if not, kills it if running
# Intended for use with Niri key binding: Mod+B { spawn "~/.config/scripts/waybar.sh"; }

# Check if Waybar is running
if pgrep -x "waybar" > /dev/null; then
    # Waybar is running, so kill it
    pkill -x waybar
    if [ $? -eq 0 ]; then
        echo "Waybar stopped."
    else
        echo "Error: Failed to stop Waybar."
        exit 1
    fi
else
    # Waybar is not running, so start it
    waybar &
    if [ $? -eq 0 ]; then
        echo "Waybar started."
    else
        echo "Error: Failed to start Waybar. Ensure it is installed."
        exit 1
    fi
fi