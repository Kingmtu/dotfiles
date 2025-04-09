#!/bin/bash

# Script to update the system using paru with clearer status messages.

# --- Configuration ---
# Add any default paru options here if needed, e.g., PARU_EXTRA_OPTS="--devel"
PARU_EXTRA_OPTS=""

# --- Check Dependencies ---
if ! command -v paru &>/dev/null; then
  printf "Error: 'paru' command not found.\n" >&2
  printf "Please install paru (AUR helper) first.\n" >&2
  exit 1
fi

# --- Check User ---
# Paru should NOT be run as root.
if [[ $EUID -eq 0 ]]; then
  printf "Error: Do not run this script as root. Run it as a regular user.\n" >&2
  printf "Paru will prompt for the sudo password when required.\n" >&2
  exit 1
fi

# --- Start Update ---
printf ":: Checking for updates and running paru -Syu...\n"
printf "   (Paru will handle repository sync, AUR checks, and updates)\n\n"

# Execute paru directly, allowing user interaction (password, confirmations)
# Pass any specified extra options and any arguments passed to the script ($@)
paru ${PARU_EXTRA_OPTS} -Syu "$@"
update_status=$? # Capture the exit code immediately after paru finishes

# --- Report Status ---
printf "\n" # Add a newline for better separation

if [ $update_status -eq 0 ]; then
  # Exit code 0 means success. This usually means either:
  # 1. Updates were successfully installed.
  # 2. The system was already up-to-date ("there is nothing to do").
  # Paru handles printing the specifics, so we just give a general success.
  printf "✅ Update check complete. System is up-to-date or updates applied successfully.\n"
  printf "   (Paru exited cleanly - check its output above for details.)\n"
else
  # Non-zero exit code indicates an error occurred during the paru process.
  printf "❌ ERROR: Paru update process failed with exit code %d.\n" "$update_status" >&2
  printf "   Please review the output above for specific error messages from paru/pacman.\n" >&2
  # Exit the script with the same error code paru returned
  exit "$update_status"
fi

# Optional: Add post-update actions here if desired (e.g., cache cleaning)

exit 0
