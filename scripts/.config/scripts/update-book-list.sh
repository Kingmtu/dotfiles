#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# Info:
#   author:    Your Name / Miroslav Vidovic (Adapted)
#   file:      update-book-list.sh
#   created:   [Date you created/modified it]
#   revision:  Robust Bash version, tool checks, error handling, mktemp
#   version:   1.2-bash
# -----------------------------------------------------------------------------
# Description:
#   Scans a directory for book files (pdf, epub, mobi) using 'find' and
#   generates a cache file for use with rofi scripts.
#   Format: 'Basename /// Full/Path'.
# Requirements:
#   find, mktemp, mv, rm, wc (standard coreutils/findutils)
# Usage:
#   ./update-book-list.sh
# -----------------------------------------------------------------------------
# Script:

# --- Configuration ---
# Directory containing your books (using $HOME is generally safer)
BOOKS_DIR="$HOME/Documents/Books/"

# Cache file location
CACHE_DIR="$HOME/.cache/rofi-scripts"
CACHE_FILE="${CACHE_DIR}/rofi-books.list"
# --- End Configuration ---

# --- Dependency Check ---
# Check for essential commands
for cmd in find mktemp mv rm wc mkdir; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: Required command '$cmd' not found in PATH." >&2
    exit 1
  fi
done
# --- End Dependency Check ---

# --- Main Logic ---
# Create cache directory if it doesn't exist
mkdir -p "$CACHE_DIR"
if [ $? -ne 0 ]; then
  echo "Error: Could not create cache directory: $CACHE_DIR" >&2
  exit 1
fi

echo "Scanning for books in: $BOOKS_DIR"
echo "Generating cache file: $CACHE_FILE"

# Use a temporary file for atomicity (prevents corrupted cache on error)
TMP_CACHE_FILE=$(mktemp "${CACHE_DIR}/rofi-books.XXXXXX")
if [ $? -ne 0 ] || [ -z "$TMP_CACHE_FILE" ]; then
  echo "Error: Could not create temporary file in $CACHE_DIR." >&2
  exit 1
fi
# Ensure temp file is removed on script exit (error or success)
# Note: This trap might not fire on extreme signals like SIGKILL
trap 'rm -f "$TMP_CACHE_FILE"' EXIT HUP INT QUIT TERM

# Find books using case-insensitive matching (-iname)
# -L follows symbolic links within BOOKS_DIR
# Output directly formatted by find -printf (efficient)
# Using 'command find' ensures we use the external binary
command find -L "$BOOKS_DIR" -type f \( -iname '*.pdf' -o -iname '*.epub' -o -iname '*.mobi' \) -printf "%f /// %p\n" >"$TMP_CACHE_FILE"
find_status=$?

# Check find command status
if [ $find_status -ne 0 ]; then
  echo "Error: 'find' command failed with status $find_status." >&2
  # Temp file will be removed by trap
  exit 1
fi

# Check if any books were found (if the temp file has size > 0)
if [ -s "$TMP_CACHE_FILE" ]; then
  # Move the temporary file to the final cache file location
  # Using mv ensures atomicity on most local filesystems
  mv "$TMP_CACHE_FILE" "$CACHE_FILE"
  if [ $? -eq 0 ]; then
    # Count lines in the final cache file
    book_count=$(wc -l <"$CACHE_FILE")
    # Remove leading/trailing whitespace from count, just in case
    book_count=$(echo "$book_count" | tr -d ' ')
    echo "Book list updated successfully. Found $book_count books."
    # Disable the exit trap since we successfully moved the file
    trap - EXIT HUP INT QUIT TERM
  else
    echo "Error: Failed to move temporary file '$TMP_CACHE_FILE' to '$CACHE_FILE'." >&2
    # Temp file will be removed by trap
    exit 1
  fi
else
  echo "Warning: No book files (.pdf, .epub, .mobi) found in $BOOKS_DIR" >&2
  # Temp file will be removed by trap
  # Keep the old cache file (if any) in this case.
  echo "Existing cache file (if any) was not modified."
fi
# --- End Main Logic ---

exit 0
