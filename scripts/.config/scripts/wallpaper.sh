#!/bin/bash

# --- Configuration ---
WALLPAPER_DIR="/home/jarvis/Pictures/wallpapers" # Replace with your wallpaper directory
# --- End Configuration ---

# Check if the wallpaper directory exists
if [ ! -d "$WALLPAPER_DIR" ]; then
  echo "Error: Wallpaper directory '$WALLPAPER_DIR' does not exist."
  exit 1
fi

# Get a random wallpaper from the directory
RANDOM_WALLPAPER=$(ls "$WALLPAPER_DIR" | shuf -n 1)

# Change the wallpaper using feh (or your preferred wallpaper manager)
feh --bg-fill "$WALLPAPER_DIR/$RANDOM_WALLPAPER"
# wallust Update
wallust pywal -i "$WALLPAPER_DIR/$RANDOM_WALLPAPER"
wal -i "$WALLPAPER_DIR/$RANDOM_WALLPAPER"
killall xfce4-panel
xfce4-panel
