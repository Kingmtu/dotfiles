#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status.
# Treat unset variables as an error when substituting.
# Pipelines return the exit status of the last command to exit non-zero.
set -euo pipefail

# --- Configuration ---
# Define search engines: ["Display Name"]="URL template where %s is replaced by the query"
# Keys are the display names shown in Rofi. Values are the URL templates.
declare -A SEARCH_ENGINES=(
  ["Brave"]='https://search.brave.com/search?q=%s'
  ["DuckDuckGo"]='https://duckduckgo.com/?q=%s'
  ["Google"]='https://www.google.com/search?q=%s'
  ["Wikipedia"]='https://en.wikipedia.org/w/index.php?search=%s'
  ["Google Scholar"]='https://scholar.google.com/scholar?hl=en&q=%s'
  ["YouTube"]='https://www.youtube.com/results?search_query=%s'
  ["GitHub"]='https://github.com/search?q=%s'
  ["Stack Overflow"]='https://stackoverflow.com/search?q=%s'
  ["Arch Wiki"]='https://wiki.archlinux.org/index.php?search=%s'
  # Add more engines here: ["Display Name"]="url_template_with_%s"
)

# Rofi theme path (Make SURE this path is correct)
ROFI_THEME="/home/jarvis/.config/rofi/launchers/styles/whale.rasi"
# ROFI_THEME="" # <-- Uncomment this line to use Rofi's default theme for testing

# Rofi prompts
ENGINE_SELECT_PROMPT=" Engine" # Link icon (adjust icon if needed)
QUERY_PROMPT=" Search"         # Web icon (adjust icon if needed)
# If icons don't display, use simple text:
# ENGINE_SELECT_PROMPT="Engine:"
# QUERY_PROMPT="Search:"

# --- Sanity Checks ---
if ! command -v rofi &>/dev/null; then
  echo "Error: 'rofi' command not found. Please install Rofi." >&2
  exit 1
fi

if ! command -v python3 &>/dev/null; then
  echo "Error: 'python3' command not found. Required for URL encoding." >&2
  exit 1
fi

# Check theme path *only if* ROFI_THEME is not empty
if [[ -n "$ROFI_THEME" && ! -f "$ROFI_THEME" ]]; then
  echo "Error: Rofi theme not found at '$ROFI_THEME'" >&2
  echo "Check the path or comment out the ROFI_THEME line to use default." >&2
  # Optional: Fallback to default theme or exit
  # ROFI_THEME="" # Uncomment to use default Rofi theme if custom is missing
  exit 1 # Exit if theme is critical
fi

# --- Helper Function for URL Encoding ---
urlencode() {
  python3 -c 'import sys, urllib.parse; print(urllib.parse.quote_plus(sys.argv[1]))' "$1"
}

# --- Stage 1: Select Search Engine ---

# Prepare the list of engine names for Rofi, sorted alphabetically
# Using process substitution <(...) is slightly cleaner than piping echo
engine_list_sorted=$(printf '%s\n' "${!SEARCH_ENGINES[@]}" | sort)

# Rofi command options for engine selection stored in an array
# Using an array prevents word splitting issues with the theme path or prompt
rofi_engine_cmd=(
  rofi
  -dmenu
  -i # Case-insensitive
  -matching fuzzy
  -location 0
  -lines "${#SEARCH_ENGINES[@]}" # Show all engines
  -p "$ENGINE_SELECT_PROMPT"
  #-theme "$ROFI_THEME" # Theme added conditionally below
)
# Conditionally add theme argument only if ROFI_THEME is set and not empty
if [[ -n "$ROFI_THEME" ]]; then
  rofi_engine_cmd+=(-theme "$ROFI_THEME")
fi

# Show Rofi menu for engine selection
# Pass the sorted list via stdin
# Capture potential errors from Rofi (like cancelling)
selected_engine_name=""
if ! selected_engine_name=$(echo -e "$engine_list_sorted" | "${rofi_engine_cmd[@]}"); then
  # Rofi exited with a non-zero status (e.g., user pressed Esc)
  echo "Search engine selection cancelled." >&2
  exit 0 # Graceful exit
fi

# Exit if the user cancelled resulting in empty output (e.g., cleared selection and pressed Enter)
# The 'set -e' handles non-zero exit, this catches empty output if user clears selection & hits enter
if [[ -z "$selected_engine_name" ]]; then
  echo "No search engine selected." >&2
  exit 0 # Exit gracefully, not an error
fi

# Validate selection against our defined engines (important with fuzzy matching)
if ! [[ -v "SEARCH_ENGINES[$selected_engine_name]" ]]; then
  echo "Error: Invalid engine selected: '$selected_engine_name'" >&2
  echo "This might happen with unusual fuzzy matching. Available engines:" >&2
  printf ' - %s\n' "${!SEARCH_ENGINES[@]}" >&2
  exit 1
fi

# --- Stage 2: Enter Search Query ---

# Get the URL template for the chosen engine
url_template="${SEARCH_ENGINES[$selected_engine_name]}"

# Customize the query prompt
dynamic_query_prompt="$QUERY_PROMPT [$selected_engine_name]:"

# Rofi command options for query input stored in an array
rofi_query_cmd=(
  rofi
  -dmenu
  -i # Case-insensitive (though less relevant for input)
  # -matching fuzzy # Fuzzy matching is usually not desired for query input
  -location 0
  -lines 0 # Single line input
  -p "$dynamic_query_prompt"
  #-theme "$ROFI_THEME" # Theme added conditionally below
)
# Conditionally add theme argument only if ROFI_THEME is set and not empty
if [[ -n "$ROFI_THEME" ]]; then
  rofi_query_cmd+=(-theme "$ROFI_THEME")
fi

# Show Rofi input for the search query
# We don't pipe anything in, just run the command
# Capture potential errors from Rofi (like cancelling)
query=""
if ! query=$("${rofi_query_cmd[@]}"); then
  # Rofi exited with a non-zero status (e.g., user pressed Esc)
  echo "Query input cancelled." >&2
  exit 0 # Graceful exit
fi

# Exit if the user cancelled or entered nothing
if [[ -z "$query" ]]; then
  echo "No query entered." >&2
  exit 0 # Exit gracefully
fi

# --- Process and Open URL ---

# URL encode the query
encoded_query=$(urlencode "$query")

# Check if encoding produced a result (should unless python errored)
if [[ -z "$encoded_query" ]] && [[ -n "$query" ]]; then
  echo "Error: Failed to URL encode the query '$query'." >&2
  exit 1
fi

# Construct the final URL by replacing %s with the encoded query
# Using bash parameter expansion: ${variable//pattern/replacement}
final_url="${url_template//%s/$encoded_query}"

echo "Selected Engine: $selected_engine_name" >&2 # Info to stderr
echo "Query: $query" >&2
echo "Opening URL: $final_url" >&2

# Open the URL in the default handler (browser)
# Check if xdg-open exists before trying to use it
if command -v xdg-open &>/dev/null; then
  # Run in background (&) and redirect stdout/stderr to /dev/null
  xdg-open "$final_url" &>/dev/null
else
  echo "Error: 'xdg-open' command not found. Cannot open URL." >&2
  echo "URL was: $final_url" >&2
  exit 1
fi

# Explicitly exit success
exit 0
