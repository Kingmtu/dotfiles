#!/usr/bin/env bash
#   NOTE: This version might list only one entry if duplicate filenames exist
#         in different subdirectories (the one processed last wins).
# Usage:
#   books-search.sh
#   books-search.sh --update  # Force update the cache
# -----------------------------------------------------------------------------
# Script:

# --- Configuration ---

# Directory containing your books (case-insensitive *.pdf search)
# Ensure this ends with a slash if you rely on that in other scripts, though not needed here.
BOOKS_DIR=~/Documents/Books/

# Cache directory and file location
CACHE_DIR="$HOME/.cache/books-search"
CACHE_FILE="$CACHE_DIR/book_map.cache" # Stores: basename<TAB>fullpath<NULL>...

# PDF Viewer command (e.g., zathura, evince, okular, xdg-open)
PDF_VIEWER="zathura"

# Rofi prompt text
ROFI_PROMPT=" " # You can change this icon/text

# Rofi theme arguments (leave empty to use default/configured Rofi theme)
ROFI_THEME_ARGS="-theme /home/jarvis/.config/rofi/launchers/styles/whale.rasi"
# ROFI_THEME_ARGS="" # Example: Use default theme

# --- Functions ---

# Function to display an error message using Rofi
# Usage: rofi_error "Your error message here"
rofi_error() {
  rofi -e "$1" $ROFI_THEME_ARGS # Pass theme args here too
}

# Function to update the book list cache
# Creates a cache file with null-separated records: basename<TAB>fullpath
# Returns 0 on success, 1 on failure.
update_cache() {
  echo "Updating book cache..." >&2
  mkdir -p "$CACHE_DIR" || {
    echo "Error: Failed to create cache directory '$CACHE_DIR'." >&2
    return 1
  }

  local temp_cache_file
  # Create a temporary file securely within the cache directory
  temp_cache_file=$(mktemp "$CACHE_DIR/temp_cache.XXXXXX")
  if [[ -z "$temp_cache_file" || ! -f "$temp_cache_file" ]]; then
    echo "Error: Failed to create temporary cache file in '$CACHE_DIR'." >&2
    return 1
  fi
  # Ensure temporary file is removed on exit or error signals
  trap 'rm -f "$temp_cache_file"' EXIT HUP INT QUIT TERM

  local file_count=0
  # Find PDF files (case-insensitive), process them safely with null delimiters
  find "$BOOKS_DIR" -type f -iname '*.pdf' -print0 |
    while IFS= read -r -d $'\0' full_path; do
      # Skip empty results just in case
      if [[ -n "$full_path" ]]; then
        local filename
        # Get the filename part
        filename=$(basename "$full_path")
        # Print "basename<TAB>fullpath<NULL>" to the temporary file, via sort
        printf '%s\t%s\0' "$filename" "$full_path"
        ((file_count++))
      fi
      # Sort the null-separated records alphabetically by filename (first field)
      # and write atomically to the temporary file
    done | sort -z >"$temp_cache_file"

  # Check if any files were processed and written to the temp file
  if [[ $file_count -gt 0 && -s "$temp_cache_file" ]]; then
    # Atomically replace the old cache file with the new one
    if mv "$temp_cache_file" "$CACHE_FILE"; then
      echo "Cache update complete ($file_count books found)." >&2
      trap - EXIT HUP INT QUIT TERM # Remove trap, temp file is now the cache
      return 0                      # Success
    else
      echo "Error: Failed to move temporary cache to '$CACHE_FILE'." >&2
      # Trap will remove the temp file
      return 1 # Failure
    fi
  elif [[ $file_count -eq 0 ]]; then
    echo "Warning: No PDF files found in '$BOOKS_DIR'. Cache file is now empty." >&2
    # Create/overwrite the cache file as empty to mark it as up-to-date
    # If mv fails here it's less critical, but we report it
    mv "$temp_cache_file" "$CACHE_FILE" || echo "Warning: Failed to create empty cache file '$CACHE_FILE'." >&2
    trap - EXIT HUP INT QUIT TERM
    return 0 # Technically success (cache reflects current state)
  else
    echo "Error: Failed to write data to temporary cache file '$temp_cache_file', though files were found." >&2
    # Trap will remove the temp file
    return 1 # Failure
  fi
}

# --- Main Script Logic ---

# 1. Ensure the books directory exists
if [[ ! -d "$BOOKS_DIR" ]]; then
  rofi_error "Books directory not found: '$BOOKS_DIR'"
  exit 1
fi

# 2. Check if cache needs updating and run update_cache if necessary
#    Update if: Cache file missing OR Books directory newer than cache OR --update flag used
if [[ ! -f "$CACHE_FILE" || "$BOOKS_DIR" -nt "$CACHE_FILE" || "$1" == "--update" ]]; then
  update_cache || exit 1 # Exit immediately if the cache update function fails critically
fi

# 3. Check if the cache file exists and is readable and non-empty after potential update
if [[ ! -r "$CACHE_FILE" ]]; then
  rofi_error "Error: Cache file is not readable: '$CACHE_FILE'"
  exit 1
elif [[ ! -s "$CACHE_FILE" ]]; then
  # Cache exists but is empty. Check if the directory is truly empty of PDFs.
  if [ -z "$(find "$BOOKS_DIR" -type f -iname '*.pdf' -print -quit)" ]; then
    rofi_error "No PDF books found in '$BOOKS_DIR'."
  else
    # This might happen if the initial scan failed silently or permissions changed
    rofi_error "Cache file is empty ('$CACHE_FILE'). Try running with --update."
  fi
  exit 1
fi

# 4. Populate the associative array mapping filename -> fullpath
#    Using Bash 4+ associative arrays for quick lookups.
declare -A book_map
while IFS=$'\t' read -r -d $'\0' filename full_path; do
  # Handle potential empty fields after splitting, though unlikely with our cache format
  if [[ -n "$filename" && -n "$full_path" ]]; then
    # Key = filename, Value = full path. Duplicates are overwritten based on sort order.
    book_map["$filename"]="$full_path"
  fi
done <"$CACHE_FILE"

# 5. Check if the map was populated successfully
if [[ ${#book_map[@]} -eq 0 ]]; then
  rofi_error "Error: Failed to read book data from cache file '$CACHE_FILE'. It might be corrupt."
  exit 1
fi

# 6. Show Rofi: Feed it only the sorted filenames (keys of the map)
#    Use process substitution for generating sorted list piped to Rofi
selected_filename=$(printf '%s\n' "${!book_map[@]}" | sort |
  rofi -dmenu \
    -i \
    -matching normal \
    -no-custom \
    -location 0 \
    -p "$ROFI_PROMPT" \
    $ROFI_THEME_ARGS) # Pass theme args

# 7. Exit if Rofi was cancelled (user pressed Esc, etc.)
if [[ -z "$selected_filename" ]]; then
  # echo "Rofi cancelled by user." >&2 # Optional: log cancellation
  exit 1
fi

# --- Action on Selection ---

# 8. Look up the full path using the selected filename from the map
selected_path="${book_map[$selected_filename]}"

# 9. Validate the looked-up path
if [[ -z "$selected_path" ]]; then
  # This case means the key didn't exist in the map, which is unexpected if selected from Rofi list
  rofi_error "Error: Internal inconsistency. Could not find path for selected book '$selected_filename'."
  exit 1
elif [[ ! -f "$selected_path" ]]; then
  # The path was found in the map, but the file doesn't exist on disk anymore
  rofi_error "Error: File not found: '$selected_path'. Book may have been moved or deleted. Try running with --update."
  exit 1
fi

# 10. Perform the clipboard operation (using your original sed logic)
echo "$selected_filename" | sed -e "s/^.... - //" -e "s/\ .*//" | xclip -selection clipboard

# 11. Open the selected book with the configured PDF viewer (run in background)
"$PDF_VIEWER" "$selected_path" &

# 12. Success
exit 0
