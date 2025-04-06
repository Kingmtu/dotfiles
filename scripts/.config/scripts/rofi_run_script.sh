#!/bin/bash
# set -e # Optional: Exit immediately if a command exits with a non-zero status.
# set -x # Optional: Uncomment for VERY verbose output (shows every command)

# --- Configuration ---
SCRIPT_DIRS=(
  "/home/jarvis/.config/scripts"      # Symlink path
  "/home/jarvis/.config/rofi/scripts" # Regular directory path
  "/home/jarvis/.local/bin"           # Regular directory path
)
THEME_PATH="/home/jarvis/.config/rofi/launchers/styles/whale.rasi"
PROMPT_TEXT="Run Script:"

# --- Debug Output (Optional: you can remove these later) ---
echo "DEBUG: Script starting."
echo "DEBUG: Searching in directories:"
printf "  - %s\n" "${SCRIPT_DIRS[@]}"
echo "DEBUG: Theme path: $THEME_PATH"
echo "DEBUG: Rofi prompt: $PROMPT_TEXT"

# --- Main Logic ---

# 1. Build the list of script filenames
echo "DEBUG: Running find command (with -H for symlinks)..."
# Use find: -H follows command-line symlinks
script_list=$(find -H "${SCRIPT_DIRS[@]}" -maxdepth 1 -type f -printf "%f\n" 2>/dev/null | sort -u)
echo "DEBUG: Find command finished."

# Check if find produced any output
if [ -z "$script_list" ]; then
  echo "DEBUG: No scripts found by find command (even with -H)."
  rofi -e "Error: No scripts found in specified directories."
  exit 1
fi

echo "DEBUG: Script list generated (what Rofi will receive):"
echo "---BEGIN LIST---"
echo "${script_list}"
echo "---END LIST---"
echo "DEBUG: Launching Rofi..."

# 2. Pipe the list to rofi
selected_script=$(echo -e "$script_list" | rofi -dmenu -p "$PROMPT_TEXT" -theme "$THEME_PATH")
rofi_exit_status=$?
echo "DEBUG: Rofi finished. Exit status: $rofi_exit_status. Selection: '$selected_script'"

# 5. Check if the user selected something
if [ $rofi_exit_status -eq 0 ] && [ -n "$selected_script" ]; then
  echo "DEBUG: User selected '$selected_script'. Searching for its full path..."
  script_to_run=""
  # 6. Find the full path of the selected script
  # NOTE: We still search the original SCRIPT_DIRS. The find -H only affected listing.
  # If the symlink target changes after listing, this could theoretically fail, but it's unlikely.
  for dir in "${SCRIPT_DIRS[@]}"; do
    # Check BOTH the directory/symlink itself AND if it's a symlink, its target
    # However, for simplicity and since find -H worked, let's assume checking the dir path is enough
    # as long as the link wasn't broken between find and now.
    potential_path="$dir/$selected_script"
    echo "DEBUG: Checking path: '$potential_path'"

    # Use readlink -f to resolve symlinks in the path before checking -x
    # But first check if the file exists at the potential path (could be in the non-symlinked dir)
    if [ -f "$potential_path" ]; then
      echo "DEBUG: Found file at '$potential_path'"
      script_to_run="$potential_path" # Store the path as found
      break                           # Found it, stop searching
    fi
  done

  # 7. Execute the script if found and executable
  if [ -n "$script_to_run" ]; then
    # Now resolve any symlinks in the FINAL path before checking execute permission
    resolved_path=$(readlink -f "$script_to_run")
    echo "DEBUG: Full path determined: '$script_to_run', resolves to: '$resolved_path'"

    # Check execute permission on the RESOLVED path
    if [ -x "$resolved_path" ]; then
      echo "DEBUG: Script IS executable. Executing '$resolved_path' in background..."
      "$resolved_path" & # Execute the resolved path
      echo "DEBUG: Execution command sent to background."
    else
      echo "DEBUG: Script found but final path IS NOT executable: '$resolved_path'"
      rofi -e "Error: '$selected_script' found but is not executable."
    fi
  else
    echo "DEBUG: ERROR: Selected script '$selected_script' could not be found in any directory after selection!"
    rofi -e "Error: Could not find '$selected_script' in directories after selection."
  fi
elif [ $rofi_exit_status -eq 1 ]; then
  echo "DEBUG: User cancelled Rofi (e.g., pressed Esc)."
else
  echo "DEBUG: Rofi exited with unexpected status: $rofi_exit_status."
fi

echo "DEBUG: Script finished."
exit 0
