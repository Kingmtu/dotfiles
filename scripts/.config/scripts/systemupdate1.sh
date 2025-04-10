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
  # Optionally, output something for Waybar if not on Arch, or just exit silently
  # echo "{ \"text\": \" N/A \", \"tooltip\": \"Not Arch Linux\" }"
  exit 0
fi

# Ensure the runtime directory exists
mkdir -p "$RUNTIME_DIR" || {
  echo "Error: Cannot create runtime directory $RUNTIME_DIR" >&2
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
  echo "Handling 'up' command..." >&2 # Add some debug output to stderr
  if [ -f "$temp_file" ]; then
    # Refreshes the Waybar module after update via signal
    # Ensure signal matches Waybar config (e.g., "signal": 20 corresponds to RTMIN+20)
    trap 'pkill -RTMIN+20 waybar' EXIT

    # Read update counts from the temp file
    official=0
    aur=0
    flatpak=0
    # Source the temp file to get the counts
    # shellcheck source=/dev/null
    source "$temp_file"

    echo "Read counts: Official=$official, AUR=$aur, Flatpak=$flatpak" >&2

    # Prepare the flatpak update command ONLY if flatpak updates were detected
    flatpak_update_cmd=""
    if pkg_installed flatpak && [ "$flatpak" -gt 0 ]; then
      flatpak_update_cmd="printf '\\n:: Checking Flatpak updates...\\n' && flatpak update --assumeyes" # Added --assumeyes for non-interactive
    fi

    # Command to execute in the terminal
    # Uses the configured AUR helper and runs flatpak update if needed
    command_to_run="
        echo '--- System Information ---'
        fastfetch --logo none --structure Title --structure Separator --structure OS --structure Kernel --structure Uptime --structure Packages --structure Shell --structure DE --structure WM --structure Terminal --structure CPU --structure GPU --structure Memory # Customize fastfetch output if desired
        echo; echo '--- Available Updates (at last check) ---'
        printf '[Official] : %s\\n[AUR]      : %s\\n[Flatpak]  : %s\\n\\n' '$official' '$aur' '$flatpak'
        echo '--- Starting full system update (Official + AUR) ---'
        ${aurhlpr} -Syu --noconfirm || echo 'Update failed. Press any key to exit.' # Added --noconfirm for non-interactive, added failure message
        ${flatpak_update_cmd} # Run flatpak update if needed
        echo; read -n 1 -p 'Update process finished. Press any key to close...'
        "

    echo "Launching terminal: $terminal" >&2
    # Execute the command in the configured terminal
    "$terminal" --title "System Update" sh -c "$command_to_run" & # Run in background to not block Waybar

    if [ $? -ne 0 ]; then
      echo "Error launching terminal '$terminal'." >&2
      # Maybe use notify-send as a fallback?
      notify-send "Update Error" "Failed to launch terminal: $terminal"
    fi

  else
    echo "Error: No update info found in $temp_file. Please wait for the module to refresh." >&2
    # Provide feedback if the temp file isn't found
    notify-send "Updater Error" "No update info found. Please wait for check."
  fi
  exit 0 # Exit after handling 'up'
fi

# --- Update Checking Logic (runs periodically via Waybar 'exec') ---

# Check Official Updates
# Use mktemp -u to avoid interfering with pacman lock database
# Redirect stderr to /dev/null to hide pacman sync db errors if network is down
ofc=$(CHECKUPDATES_DB=$(mktemp -u) checkupdates 2>/dev/null | wc -l)

# Check AUR Updates (use the configured helper)
# Add error handling in case the command fails (e.g., network down)
aur_output=$(${aurhlpr} -Qua 2>/dev/null)
aur_exit_code=$?
if [ $aur_exit_code -eq 0 ]; then
  aur=$(echo "$aur_output" | wc -l)
else
  aur=0 # Report 0 AUR updates if the check failed
  echo "Warning: AUR check command ('${aurhlpr} -Qua') failed with exit code $aur_exit_code." >&2
fi

# Check Flatpak Updates
fpk=0
fpk_disp=""
if pkg_installed flatpak; then
  # Add error handling
  fpk_output=$(flatpak remote-ls --updates 2>/dev/null)
  fpk_exit_code=$?
  if [ $fpk_exit_code -eq 0 ]; then
    fpk=$(echo "$fpk_output" | wc -l)
    [ "$fpk" -gt 0 ] && fpk_disp="\n󰏓 Flatpak $fpk" # Show flatpak count only if > 0
  else
    fpk=0 # Report 0 if check failed
    echo "Warning: Flatpak check command failed with exit code $fpk_exit_code." >&2
  fi
else
  fpk=0
  fpk_disp=""
fi

# Calculate total available updates
upd=$((ofc + aur + fpk))

# Prepare the upgrade info content
upgrade_info=$(
  cat <<EOF
OFFICIAL_UPDATES=$ofc
AUR_UPDATES=$aur
FLATPAK_UPDATES=$fpk
EOF
)

# Save the upgrade info for the 'up' command
echo "$upgrade_info" >"$temp_file"

# --- Output JSON for Waybar ---
if [ "$upd" -eq 0 ]; then
  # Option 1: Show nothing
  echo "{ \"text\": \"\", \"tooltip\": \"󁘡 System is up to date\" }"
  # Option 2: Show only an icon
  # echo "{ \"text\": \"󰮯\", \"tooltip\": \"󁘡 System is up to date\" }"
else
  # Tooltip shows breakdown
  tooltip="󱓽 Official $ofc\n󱓾 AUR $aur$fpk_disp"
  # Text shows icon and total count
  echo "{\"text\":\"󰮯 $upd\", \"tooltip\":\"$tooltip\"}"
fi

exit 0
