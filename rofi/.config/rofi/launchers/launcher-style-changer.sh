#!/usr/bin/env bash
#  ┳┓┏┓┏┓┳  ┓ ┏┓┳┳┳┓┏┓┓┏┏┓┳┓  ┏┓┏┳┓┓┏┓ ┏┓  ┏┓┏┓┓ ┏┓┏┓┏┳┓┏┓┳┓
#  ┣┫┃┃┣ ┃━━┃ ┣┫┃┃┃┃┃ ┣┫┣ ┣┫━━┗┓ ┃ ┗┫┃ ┣ ━━┗┓┣ ┃ ┣ ┃  ┃ ┃┃┣┫
#  ┛┗┗┛┻ ┻  ┗┛┛┗┗┛┛┗┗┛┛┗┗┛┛┗  ┗┛ ┻ ┗┛┗┛┗┛  ┗┛┗┛┗┛┗┛┗┛ ┻ ┗┛┛┗
#

# Copyright: The Hyde Project
# Purpose: Select a Rofi theme style visually (with base name labels, original layout) and apply it to launcher.sh
# Dependency: rofi, sed, notify-send, find, sort, basename
# Optional: wlr-randr, jq, bc (for dynamic sizing on wlroots compositors like Niri/Sway)

# --- Rofi Variables ---
rofiAssetDir="${HOME}/.config/rofi/launchers/assets"
rofiTheme="${HOME}/.config/rofi/applets/rofiSelect.rasi"
targetScript="${HOME}/.config/rofi/launchers/launcher.sh"
notificationAppName="RofiStyleSelector"
notificationID=91190 # Unique ID for notifications

# --- Configuration ---
# Font Settings - KEPT FROM PREVIOUS CHANGES
theme_font="JetBrains Mono"
theme_font_size="10" # Adjust font size as needed (e.g., 9, 10, 11)

# Fallback settings (if dynamic sizing fails) - REVERTED
default_col_count=3
default_window_width="80%"

# Dynamic sizing settings (Estimations - reverted to original values) - REVERTED
font_scale=10                     # Base scale factor for pixel estimations
element_padding_factor=2          # Pixels of padding per font_scale unit *around* the element container
estimated_icon_width_factor=15    # Estimated width factor for the icon content (moderate size)
estimated_text_width_factor=10    # Estimated width factor for the text label (kept as text is visible)
total_horizontal_padding_factor=4 # Total window horizontal padding per font_scale (left + right)

# Clamp dynamically calculated columns - REVERTED
max_cols=5
min_cols=2

# Icon size in the Rofi menu - REVERTED (using dynamic factor)
icon_size_css="calc(${estimated_icon_width_factor} * ${font_scale}px)"
# Or set a moderate fixed size like: icon_size_css="48px" or "3em"

# --- Dependency Checks ---
# Essential tools
for cmd in rofi sed notify-send find sort basename; do
  if ! command -v "$cmd" >/dev/null; then
    echo "Error: Essential command '$cmd' not found." >&2
    notify-send -u critical -a "$notificationAppName" -r "$notificationID" "Error: Dependency '$cmd' not found."
    exit 1
  fi
done

# Check asset directory
if [ ! -d "$rofiAssetDir" ]; then
  echo "Error: Rofi asset directory not found: $rofiAssetDir" >&2
  notify-send -u critical -a "$notificationAppName" -r "$notificationID" "Error: Rofi assets not found at '$rofiAssetDir'"
  exit 1
fi

# --- Dynamic Sizing Attempt (using wlr-randr for Wayland/wlroots) - REVERTED LOGIC ---
col_count=$default_col_count
window_width_css=$default_window_width # Use CSS compatible width string
dynamic_width_calculated=false

# Check for optional tools needed for dynamic sizing
if command -v wlr-randr >/dev/null && command -v jq >/dev/null && command -v bc >/dev/null; then
  monitor_data=$(wlr-randr --json | jq -r '.[] | select(.primary==true or .active==true) | "\(.width // 0) \(.height // 0) \(.transform // "normal") \(.scale // 1.0)"' | head -n 1)
  read -r mon_w mon_h mon_transform mon_scale <<<"$monitor_data"

  if [[ -n "$mon_w" && "$mon_w" -gt 0 && -n "$mon_h" && "$mon_h" -gt 0 && -n "$mon_scale" && "$(echo "$mon_scale > 0" | bc -l)" -eq 1 ]]; then
    if [[ "$mon_transform" == "90" || "$mon_transform" == "270" || "$mon_transform" == "flipped-90" || "$mon_transform" == "flipped-270" ]]; then
      phys_width=$mon_h
    else
      phys_width=$mon_w
    fi
    logical_width=$(echo "scale=0; $phys_width / $mon_scale" | bc)

    if [[ "$logical_width" -gt 0 ]]; then
      # Estimate element width using icon estimate + padding (original approach)
      padding_px=$((element_padding_factor * 2 * font_scale))
      icon_width_px=$((estimated_icon_width_factor * font_scale))
      elm_width=$((icon_width_px + padding_px)) # Simplified width estimate based on icon

      total_window_padding_px=$((total_horizontal_padding_factor * font_scale))
      max_avail=$((logical_width - total_window_padding_px))

      if [[ "$elm_width" -gt 0 && "$max_avail" -gt "$elm_width" ]]; then
        calculated_cols=$((max_avail / elm_width))
        # Clamp columns using original limits
        [[ "$calculated_cols" -lt "$min_cols" ]] && calculated_cols="$min_cols"
        [[ "$calculated_cols" -gt "$max_cols" ]] && calculated_cols="$max_cols"
        [[ "$calculated_cols" -lt 1 ]] && calculated_cols=1 # Ensure at least one column

        col_count=$calculated_cols

        # Calculate window width based on columns, element width, and padding (original simpler calc)
        calculated_width_px=$(((col_count * elm_width) + total_window_padding_px))
        window_width_css="${calculated_width_px}px"
        dynamic_width_calculated=true
        echo "Info: Dynamically calculated $col_count columns (original layout), window width ${window_width_css} based on primary monitor ($logical_width logical px width)." >&2
      else
        echo "Warning: Could not calculate columns (elm_width=$elm_width, max_avail=$max_avail <= elm_width). Using defaults." >&2
        col_count=$default_col_count           # Revert to default cols if calculation fails
        window_width_css=$default_window_width # Revert to default width
      fi
    else
      echo "Warning: Could not determine positive logical width ($logical_width). Using defaults." >&2
    fi
  else
    echo "Warning: Failed to get valid monitor data (w=$mon_w, h=$mon_h, scale=$mon_scale) via wlr-randr. Using defaults." >&2
  fi
else
  echo "Info: Optional tools wlr-randr, jq, or bc not found. Using default fixed layout." >&2
fi

# --- Generate Rofi Theme Override ---
elem_border=$((font_scale / 2))
icon_border=$elem_border
element_padding_css="0.5em" # Reverted padding
icon_spacing_css="0.3em"    # Reverted space below icon

# REVERTED to original spacing/padding values, KEPT font setting
r_override="window{ width: ${window_width_css}; }
listview{ columns: ${col_count}; spacing: 1em; /* Reverted spacing */ }
element{
    orientation: vertical;
    border-radius: ${elem_border}px;
    padding: ${element_padding_css}; /* Reverted padding */
}
element-icon{
    border-radius: ${icon_border}px;
    size: ${icon_size_css}; /* Use reverted icon size */
    margin: 0 0 ${icon_spacing_css} 0; /* Reverted space below icon */
    horizontal-align: 0.5; /* Center icon */
    expand: false;
}
element-text{
    horizontal-align: 0.5; /* Center text */
    vertical-align: 0.5;
    font: \"${theme_font} ${theme_font_size}\"; /* <<< KEPT FONT SETTING */
    /* color: #cccccc; */
}"

# --- Prepare and Show Rofi Menu ---

mapfile -t style_files < <(find -L "$rofiAssetDir" -maxdepth 1 -type f -name '*.png')

if [ ${#style_files[@]} -eq 0 ]; then
  echo "Error: No PNG style files found in $rofiAssetDir" >&2
  notify-send -u normal -a "$notificationAppName" -r "$notificationID" "No Rofi styles (PNGs) found" "Please check '$rofiAssetDir'"
  exit 1
fi

style_names=()
for file in "${style_files[@]}"; do
  if [[ -n "$file" ]]; then
    style_names+=("$(basename "$file")")
  fi
done
IFS=$'\n' style_names_sorted=($(sort -V <<<"${style_names[*]}"))
unset IFS

# Prepare the list for Rofi: display base name, use full path for icon - KEPT
rofi_list=""
for style_name_with_ext in "${style_names_sorted[@]}"; do
  if [ -n "$style_name_with_ext" ]; then
    icon_path="${rofiAssetDir}/${style_name_with_ext}"
    display_name="${style_name_with_ext%.png}" # <<< KEPT: display name without extension
    rofi_list+="${display_name}\x00icon\x1f${icon_path}\n"
  fi
done

# Present Rofi menu
RofiSel=$(echo -en "$rofi_list" | rofi -dmenu -markup-rows -theme-str "$r_override" -theme "$rofiTheme")

# --- Apply Selection ---
# KEPT: Handles selection being the base name
if [ -n "${RofiSel}" ]; then
  RofiBaseName="${RofiSel}" # <<< KEPT: Selection is base name
  full_filename="${RofiBaseName}.png"
  iconPath="${rofiAssetDir}/${full_filename}"

  if [ ! -f "$targetScript" ]; then
    echo "Error: Target script not found: $targetScript" >&2
    notify-send -u critical -a "$notificationAppName" -r "$notificationID" "Error: Target script not found" "'$targetScript' is missing."
    exit 1
  fi

  if [ ! -f "$iconPath" ]; then
    echo "Warning: Selected icon file seems missing: $iconPath" >&2
    iconPath="dialog-information" # Fallback icon
  fi

  sed -i "s|style_theme='.*'|style_theme='${RofiBaseName}'|" "$targetScript"

  if [ $? -eq 0 ]; then
    notify-send -e -h string:x-canonical-private-synchronous:rofi_notif \
      -a "$notificationAppName" -r "$notificationID" -t 2200 \
      -i "$iconPath" "Rofi style updated" "'${RofiBaseName}' applied successfully."
  else
    echo "Error: Failed to update '$targetScript' with sed." >&2
    notify-send -e -a "$notificationAppName" -r "$notificationID" -t 3000 \
      -u critical "Error applying Rofi style" "Failed to update '${targetScript}' for style '${RofiBaseName}'."
    exit 1
  fi
fi

exit 0
