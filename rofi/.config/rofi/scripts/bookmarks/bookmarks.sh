#!/bin/sh

# Define the theme file name (adjust if your file is named differently)
THEME_FILE="whale.rasi" # Or "whale_v4.rasi", etc.

# Construct the full path to the theme file relative to the script's directory
THEME_PATH="$(dirname "$0")/${THEME_FILE}"

# Check if the theme file actually exists
if [ ! -f "${THEME_PATH}" ]; then
  echo "Error: Rofi theme file not found at ${THEME_PATH}" >&2
  # Optionally, fall back to default theme or exit
  # rofi_cmd="rofi -dmenu -i -p ''"
  exit 1
  # else
  # Theme found, use it in the command
  # rofi_cmd="rofi -dmenu -i -p '' -theme '${THEME_PATH}'"
fi

# Original logic using the theme
ADDRESS=$(cat "$(dirname "$0")/bookmarks.txt" | rofi -dmenu -i -p "" -theme "${THEME_PATH}")

# Check if ADDRESS is not empty after potential cut/processing
if [ -n "$ADDRESS" ]; then
  # Extract the actual URL part after the last '-' (assuming format like 'Name - URL')
  # Adjust the 'cut' command if your bookmarks.txt format is different
  URL=$(echo "$ADDRESS" | cut -d'-' -f2- | sed 's/^[[:space:]]*//') # cut and remove leading space

  if [ -n "$URL" ]; then
    # Use your preferred browser command
    thorium-browser "$URL" # Removed -e, assuming it's not needed or was a typo? Use if required by thorium.
    # Switch workspace if needed
    i3-msg workspace number 2 # Or whatever workspace command you use
  fi
fi
