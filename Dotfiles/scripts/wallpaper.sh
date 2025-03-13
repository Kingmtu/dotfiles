#!/bin/bash

# --- Configuration ---
WALLPAPER_DIR="/home/jarvis/Pictures/wallpapers"  # Replace with your wallpaper directory
# --- End Configuration ---

# Check if the wallpaper directory exists
if [ ! -d "$WALLPAPER_DIR" ]; then
  echo "Error: Wallpaper directory '$WALLPAPER_DIR' does not exist."
  exit 1
fi

# Get a random wallpaper from the directory
RANDOM_WALLPAPER=$(ls "$WALLPAPER_DIR" | shuf -n 1)

# Change the wallpaper using feh (or your preferred wallpaper manager)
feh -z --bg-fill "$WALLPAPER_DIR/$RANDOM_WALLPAPER"

# Run pywal to update colors
wal --cols16 -i "$WALLPAPER_DIR/$RANDOM_WALLPAPER"
# wallust Update
wallust run "$WALLPAPER_DIR/$RANDOM_WALLPAPER"
#i3 Reload 
i3-msg reload
i3-msg restart

killall xfce4-panel
xfce4-panel