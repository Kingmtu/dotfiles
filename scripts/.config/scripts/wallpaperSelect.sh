#!/usr/bin/env bash

# Wallpapers Path
wallpaperDir="$HOME/Pictures/wallpapers"
themesDir="$HOME/.config/rofi/launchers/type-3"

# Transition config
FPS=60
TYPE="any"
DURATION=3
BEZIER="0.4,0.2,0.4,1.0"
AWWW_PARAMS="--transition-fps ${FPS} --transition-type ${TYPE} --transition-duration ${DURATION} --transition-bezier ${BEZIER}"

# 1. Ensure wallpaper directory exists
if [ ! -d "$wallpaperDir" ]; then
  notify-send "Error" "Wallpaper directory not found: $wallpaperDir"
  exit 1
fi

# 2. Start the daemon if it's not running (Replaces the broken 'awww init')
if ! pgrep -x "awww-daemon" >/dev/null; then
  awww-daemon &
  sleep 0.5 # Give the socket a moment to initialize
fi

# 3. Retrieve image files (Handles spaces in filenames)
mapfile -t PICS < <(find -L "$wallpaperDir" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \) | sort)

randomChoice="[${#PICS[@]}] Random"
randomPicture="${PICS[$((RANDOM % ${#PICS[@]}))]}"
rofiCommand="rofi -show -dmenu -theme ${themesDir}/style-4.rasi"

# Function to apply wallpaper
executeCommand() {
  local pic="$1"

  # Try awww first, fallback to swaybg
  if command -v awww &>/dev/null; then
    awww img "$pic" ${AWWW_PARAMS}
  elif command -v swaybg &>/dev/null; then
    pkill swaybg
    swaybg -i "$pic" &
  fi

  # Update symlink and colors
  ln -sf "$pic" "$HOME/.current_wallpaper"
  if command -v wallust &>/dev/null; then
    wallust run "$HOME/.current_wallpaper"
  fi
}

# Rofi Menu Generator
menu() {
  echo "$randomChoice"
  for file in "${PICS[@]}"; do
    printf "%s\x00icon\x1f%s\n" "$(basename "$file")" "$file"
  done
}

# Execution Logic
main() {
  if pidof rofi >/dev/null; then
    pkill rofi
    exit 0
  fi

  choice=$(menu | ${rofiCommand})
  [[ -z "$choice" ]] && exit 0

  if [[ "$choice" == "$randomChoice" ]]; then
    executeCommand "$randomPicture"
    exit 0
  fi

  for file in "${PICS[@]}"; do
    if [[ "$(basename "$file")" == "$choice" ]]; then
      executeCommand "$file"
      exit 0
    fi
  done
}

main
