#!/bin/bash
# --- Configuration ---
WALLPAPER_DIR="/home/jarvis/Pictures/wallpapers" # Replace with your wallpaper directory
# --- End Configuration ---

# Check if the wallpaper directory exists
if [ ! -d "$WALLPAPER_DIR" ]; then
  echo "Error: Wallpaper directory '$WALLPAPER_DIR' does not exist."
  exit 1
fi

RANDOM_WALLPAPER=$(ls "$WALLPAPER_DIR" | shuf -n 1)

#swaybg -i -m fill "$WALLPAPER_DIR/$RANDOM_WALLPAPER"
swww query || swww-daemon
swww img "$WALLPAPER_DIR/$RANDOM_WALLPAPER" --transition-fps 30 --transition-type any --transition-duration 3
wallust pywal -i "$WALLPAPER_DIR/$RANDOM_WALLPAPER"
#matugen image "$WALLPAPER_DIR/$RANDOM_WALLPAPER"
