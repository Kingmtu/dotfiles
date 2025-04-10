#!/usr/bin/env bash

# --- Configuration ---
# Set your preferred AUR helper command (e.g., yay, paru, trizen)
aurhlpr="paru"
# Set your preferred terminal emulator (e.g., kitty, foot, alacritty, gnome-terminal)
terminal="kitty"
# Set the runtime directory for storing update counts
# Using /run/user/$UID is generally preferred for temporary runtime data
RUNTIME_DIR="/run/user/$(id -u)/waybar-updater"
# --- End Configuration ---

# Check if running on Arch Linux
if [ ! -f /etc/arch-release ]; then
  # Output nothing for Waybar if not on Arch
  exit 0
fi

# Ensure the runtime directory exists
mkdir -p "$RUNTIME_DIR" || {
  echo "Error: Cannot create runtime directory $RUNTIME_DIR" >&2
  # Optionally send a notification
  # notify-send "Waybar Updater Error" "Cannot create runtime directory $RUNTIME_DIR"
  exit 1
}
temp_file="$RUNTIME_DIR/update_info"

# --- Helper Functions ---
# Function to check if a package is installed (using pacman)
pkg_installed() {
  pacman -Q "$1" &>/dev/null
}
# Export the function so it's available in subshells (needed for the 'up' command's flatpak check)
export -f pkg_installed

# --- Main Logic ---

# Handle the 'up' command (triggered by Waybar on-click)
if [ "$1" == "up" ]; then
  echo "Handling 'up' command..." >&2 # Debug output

  if [ -f "$temp_file" ]; then
    # Refreshes the Waybar module after update via signal
    # Ensure signal matches Waybar config (e.g., "signal": 20 corresponds to RTMIN+20)
    # This runs when the terminal *launched by this script* exits.
    trap 'pkill -RTMIN+20 waybar' EXIT

    # Read update counts stored by the last periodic check
    official_count=0
    aur_count=0
    flatpak_count=0
    # Source the temp file to get the counts
    # shellcheck source=/dev/null
    source "$temp_file"

    echo "Read counts from $temp_file: Official=$official_count, AUR=$aur_count, Flatpak=$flatpak_count" >&2

    # --- Prepare Terminal Command ---
    # Initialize Flatpak command as empty
    flatpak_update_cmd=""
    # Check if flatpak is installed AND the count from the file indicates updates were found
    if pkg_installed flatpak && [ "$flatpak_count" -gt 0 ]; then
      # Prepare the non-interactive Flatpak update command
      flatpak_update_cmd="printf '\\n:: Checking and applying Flatpak updates...\\n' && flatpak update --assumeyes"
      echo "Flatpak updates detected ($flatpak_count), preparing update command." >&2
    else
      echo "No Flatpak updates detected or Flatpak not installed." >&2
    fi

    # Construct the full command to run in the terminal
    # Uses the configured AUR helper (non-interactive) and runs flatpak update if prepared
    # Displays the counts read from the temp file
    command_to_run="
        echo '--- System Information ---'
        fastfetch --logo none --structure Title --structure Separator --structure OS --structure Kernel --structure Uptime --structure Packages --structure Shell --structure DE --structure WM --structure Terminal --structure CPU --structure GPU --structure Memory # Customize fastfetch output if desired
        echo; echo '--- Available Updates (as of last check) ---'
        printf '[Official] : %s\\n[AUR]      : %s\\n[Flatpak]  : %s\\n\\n' '$official_count' '$aur_count' '$flatpak_count' # Display counts from file
        echo '--- Starting Package Sync and Update (Official + AUR) ---'
        # Run AUR helper sync & update, non-interactively
        ${aurhlpr} -Syu --noconfirm || { echo; echo '*** Pacman/AUR Helper update command failed. Check output above. ***'; }
        # Execute the prepared flatpak command (if any)
        ${flatpak_update_cmd}
        echo
        read -n 1 -s -r -p 'Update process finished. Press any key to close this terminal...'
        " # -s: silent, -r: raw input

    echo "Launching terminal: $terminal with update command" >&2
    # Execute the command in the configured terminal, run in background (&) to not block Waybar
    "$terminal" --title "System Update" sh -c "$command_to_run" &

    terminal_launch_status=$?
    if [ $terminal_launch_status -ne 0 ]; then
      echo "Error launching terminal '$terminal' (Exit code: $terminal_launch_status)." >&2
      # Use notify-send as a fallback notification mechanism
      notify-send -u critical "Waybar Update Error" "Failed to launch terminal: $terminal"
    fi

  else
    echo "Error: Update info file '$temp_file' not found. Cannot start update." >&2
    # Provide feedback if the temp file isn't found when clicking
    notify-send "Waybar Updater Error" "No update info found. Please wait for the next check."
  fi
  exit 0 # Exit after handling 'up'
fi

# --- Update Checking Logic (runs periodically via Waybar 'exec') ---

# Check Official Updates
ofc=0 # Default to 0
# Use checkupdates (safer than pacman -Sy directly)
ofc_output=$(checkupdates 2>/dev/null)
ofc_exit_code=$?
if [ $ofc_exit_code -eq 0 ]; then
  if [ -n "$ofc_output" ]; then ofc=$(echo "$ofc_output" | wc -l); else ofc=0; fi
elif [ $ofc_exit_code -eq 2 ]; then
  ofc=0 # Exit code 2 means no updates
else
  ofc=0
  echo "Warning: Official check command ('checkupdates') failed with exit code $ofc_exit_code." >&2
fi

# Check AUR Updates (use the configured helper)
aur=0 # Default to 0
if command -v "${aurhlpr}" &>/dev/null; then
  aur_output=$(${aurhlpr} -Qua 2>/dev/null)
  aur_exit_code=$?
  if [ $aur_exit_code -eq 0 ]; then
    if [ -n "$aur_output" ]; then aur=$(echo "$aur_output" | wc -l); else aur=0; fi
  else
    aur=0
    echo "Warning: AUR check command ('${aurhlpr} -Qua') failed with exit code $aur_exit_code." >&2
  fi
else
  aur=0
  echo "Warning: Configured AUR helper '${aurhlpr}' not found or not executable." >&2
fi

# Check Flatpak Updates
fpk=0       # Default to 0
fpk_disp="" # Tooltip display string for flatpak
if pkg_installed flatpak; then
  fpk_output=$(flatpak remote-ls --updates 2>/dev/null)
  fpk_exit_code=$?
  if [ $fpk_exit_code -eq 0 ]; then
    if [ -n "$fpk_output" ]; then
      fpk=$(echo "$fpk_output" | wc -l)
      # Use Flatpak icon () in tooltip if updates > 0
      [ "$fpk" -gt 0 ] && fpk_disp="\n Flatpak $fpk"
    else fpk=0; fi
  else
    fpk=0
    echo "Warning: Flatpak check command ('flatpak remote-ls --updates') failed with exit code $fpk_exit_code." >&2
  fi
else
  fpk=0
  fpk_disp=""
fi # Flatpak not installed

# Calculate total available updates
upd=$((ofc + aur + fpk))

# Prepare the update info content to be stored
update_info=$(
  cat <<EOF
official_count=$ofc
aur_count=$aur
flatpak_count=$fpk
EOF
)

# Save the update info for the 'up' command to read later
echo "$update_info" >"$temp_file" || {
  echo "Error: Failed to write update info to $temp_file" >&2
  exit 1 # Exit if we can't save the info
}

# --- Output JSON for Waybar ---
# Use Pacman-themed icons (ensure your font supports these glyphs)
#  Ghost (Updates available)
# ᗧ Pacman char (Up-to-date)
#  Arch logo (Official)
#  User icon (AUR)
#  Flatpak logo (Flatpak)

if [ "$upd" -eq 0 ]; then
  # Use Pacman character icon for text when up-to-date
  echo "{ \"text\": \"\", \"tooltip\": \"No Updates Available\" }"
else
  # Tooltip shows breakdown with new icons
  tooltip=" Official $ofc\n AUR $aur$fpk_disp" # fpk_disp includes Flatpak line (with icon) if needed
  # Text shows Ghost icon and total count
  echo "{\"text\":\" $upd\", \"tooltip\":\"$tooltip\"}"
fi

exit 0
