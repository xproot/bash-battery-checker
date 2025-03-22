#!/bin/bash

# Default options
COLOR=true
TEXT_ONLY=false
DETAILED=false
WATCH=false
WIDTH=$(tput cols 2>/dev/null || echo 0)  # Default width to terminal width
BATTERIES=()

# ANSI color codes
RESET="\e[0m"
BOLD="\e[1m"
GREEN="\e[32m"
BGREEN="\033[42m"
LIGHT_GREEN="\e[92m"
BLIGHT_GREEN="\e[102m"
YELLOW="\e[33m"
BYELLOW="\e[43m"
RED="\e[31m"
BRED="\e[41m"
LIGHT_RED="\e[91m"
BLIGHT_RED="\e[101m"

# Usage function
usage() {
  cat <<EOF
Usage: battery.sh [options] [battery...]

Options:
  --no-color       Disable colored output
  --color          Force enable colored output
  --text-only      Display information in plain text only
  --detailed       Show detailed battery information
  --help           Show this help message
  --watch          Watch for changes and update information
  --width <width>  Set width for progress bars (ignored in text-only mode)

If no batteries are specified, all available batteries will be shown.
EOF
}

# If the width is less than one, enable text only mode (default width is 0, so this means the terminal did not reply to us asking for the width)
if [[ "$WIDTH" -lt 1 ]]; then
  TEXT_ONLY=true
fi

# Toggle colors depending on capabilities (old code? default is color on)
if [ "$TERM" = "xterm-256color" ]; then
    COLOR=true
elif [[ "$TERM" = "xterm" ]]; then
    # Query the terminal's color capabilities for color index 42
    printf '\033]4;%d;?\007' 42
    # Read the terminal's response
    if read -d $'\007' -s -t 1; then
      COLOR=true
    else
      COLOR=false
    fi
else
    COLOR=false
fi

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --no-color)
      COLOR=false
      RESET=""
      BOLD=""
      BGREEN=""
      GREEN=""
      BLIGHT_GREEN=""
      LIGHT_GREEN=""
      BYELLOW=""
      YELLOW=""
      BRED=""
      RED=""
      BLIGHT_RED=""
      LIGHT_RED=""
      ;;
    --color)
      COLOR=true
      ;;
    --text-only)
      COLOR=false
      TEXT_ONLY=true
      ;;
    --detailed)
      DETAILED=true
      ;;
    --help)
      usage
      exit 0
      ;;
    --watch)
      WATCH=true
      ;;
    --width)
      shift
      WIDTH=$1
      ;;
    *)
      BATTERIES+=("$1")
      ;;
  esac
  shift
done

# Function to calculate the static width (without including colors)
calculate_static_width() {
  local battery=$1
  local status=$2
  local capacity=$3
  echo $(( ${#battery} + ${#status} + ${#capacity} + 12 ))  # Add fixed characters like ": , % []"
}

# NOTE: There's way too many of these
# Function to get color for battery status
get_status_color() {
  local status=$1
  case $status in
    "Charging") echo "$GREEN" ;;
    "Full") echo "$BOLD$LIGHT_GREEN" ;;
    "Discharging") echo "$LIGHT_RED" ;;
    *) echo "$BOLD" ;;
  esac
}

# Function to get gradient color for progress bar
get_progress_color() {
  if [ "$COLOR" = true ]; then
    local percent=$1
    if [[ "$percent" == "N/A" ]]; then
      echo "$BOLD"
    elif [[ $percent -lt 20 ]]; then
      echo "$RED"
    elif [[ $percent -lt 50 ]]; then
      echo "$YELLOW"
    elif [[ $percent -lt 75 ]]; then
      echo "$GREEN"
    else
      echo "$LIGHT_GREEN"
    fi
  fi
}
get_progress_background_color() {
  if [ "$COLOR" = true ]; then
    local percent=$1
    if [[ $percent -lt 20 ]]; then
      echo "$BRED"
    elif [[ $percent -lt 50 ]]; then
      echo "$BYELLOW"
    elif [[ $percent -lt 75 ]]; then
      echo "$BGREEN"
    else
      echo "$BLIGHT_GREEN"
    fi
  fi
}
# If value < minimum, y e l l o w. Otherwise green!
get_color_with_minimum() {
  if [ "$COLOR" = true ]; then
    local current=$1
    local minimum=$2
    if [[ $current -lt $minimum ]]; then
      echo "$YELLOW"
    else 
      echo "$GREEN"
    fi
  fi
}

# Convert a µ reading to a base unit reading, with decimals!
unmicro_int() {
  local microunit=$1 # Base number (assumed in microunits)
  local mainunit=$(( microunit / 1000000 )) # Number before the decimal point, in other words, the integer.
  local decimalsunit=${microunit:${#mainunit}} # Number after the decimal point, in other words, the decimals.
  [[ "$mainunit" -lt 1 ]] && decimalsunit="$microunit" # Characters in the $mainunit variable will always be >0, so this undoes the substring (this could be an if/else)
  decimalsunit=$(printf "$decimalsunit" | sed 's/0*$//') # Removes zeroes on the end, they're redundant.
  [[ "${#microunit}" -lt 6 ]] && for ((i=1;i<=$(( 6 - ${#microunit} ));i++)); do decimalsunit=0${decimalsunit}; done # Adds zeroes in front, if the microunit variable is smaller than a base unit.
  [[ -z "$decimalsunit" ]] && decimalsunit=0 # If somehow decimalsunit fails to be set until now, it is set to 0.
  echo "$mainunit.$decimalsunit" # "12.0V", for example. The zero is a design choice but it also makes the code simpler.
}

# Function to get battery information (main function?)
get_battery_info() {
  local battery=$1
  local path="/sys/class/power_supply/$battery"

  if [[ ! -d $path ]]; then
    echo "Battery $battery not found." >&2
    return
  fi

  local name=$(cat "$path/manufacturer" 2>/dev/null | tr '\n' ' ' && cat "$path/model_name" 2>/dev/null || echo "N/A")
  local technology=$(cat "$path/technology" 2>/dev/null || echo "N/A")
  local type=$(cat "$path/type" 2>/dev/null || echo "N/A")
  local status=$(cat "$path/status" 2>/dev/null || echo "N/A")
  local capacity=$(cat "$path/capacity" 2>/dev/null || echo "N/A")

  local charge_now=$(cat "$path/charge_now" 2>/dev/null || echo "")
  local charge_full=$(cat "$path/charge_full" 2>/dev/null || echo "")
  local energy_now=$(cat "$path/energy_now" 2>/dev/null || echo "")
  local energy_full=$(cat "$path/energy_full" 2>/dev/null || echo "")
  local charge_full_design=$(cat "$path/charge_full_design" 2>/dev/null || echo "")
  local energy_full_design=$(cat "$path/energy_full_design" 2>/dev/null || echo "")
  local cycle_count=$(cat "$path/cycle_count" 2>/dev/null || echo "")
  local voltage_now=$(cat "$path/voltage_now" 2>/dev/null || echo "")
  local voltage_min_design=$(cat "$path/voltage_min_design" 2>/dev/null || echo "1")
  local current_now=$(cat "$path/current_now" 2>/dev/null || echo "")
  local power_now=$(cat "$path/power_now" 2>/dev/null || echo "")

  # Calculate health percentages for charge and energy
  local health_charge="N/A"
  local health_energy="N/A"
  if [[ -n $charge_full_design && -n $charge_full && $charge_full -gt 0 ]]; then
    health_charge=$((100 * charge_full / charge_full_design))
  fi
  if [[ -n $energy_full_design && -n $energy_full && $energy_full -gt 0 ]]; then
    health_energy=$((100 * energy_full / energy_full_design))
  fi

  # Determine which unit to display (amps, watts, or none)
  local capacity_detail="N/A"
  if [[ -n $charge_now && -n $energy_now ]]; then
    capacity_detail="$(unmicro_int "$charge_now")Ah / $(unmicro_int "$charge_full")Ah and $(unmicro_int "$energy_now")Wh / $(unmicro_int "$energy_full")Wh"
  elif [[ -n $charge_now ]]; then
    capacity_detail="$(unmicro_int "$charge_now")Ah / $(unmicro_int "$charge_full")Ah"
  elif [[ -n $energy_now ]]; then
    capacity_detail="$(unmicro_int "$energy_now")Wh / $(unmicro_int "$energy_full")Wh"
  fi

  # Determine health details
  local health_detail="N/A"
  if [[ -n $charge_full_design || -n $energy_full_design ]]; then
    health_detail=""
    if [[ -n $charge_full_design && -n $charge_full ]]; then
      health_detail+="$(get_progress_color "$health_charge")$health_charge%$RESET ($(unmicro_int "$charge_full")Ah / $(unmicro_int "$charge_full_design")Ah)"
    fi
    if [[ -n $energy_full_design && -n $energy_full ]]; then
      [[ -n $health_detail ]] && health_detail+=" and "
      health_detail+="$(get_progress_color "$health_energy")$health_energy%$RESET ($(unmicro_int "$energy_full")Wh / $(unmicro_int "$energy_full_design")Wh)"
    fi
    if [[ -n $cycle_count ]]; then
      health_detail+=", $cycle_count cycles"
    fi
  fi

  # Determine power details
  local power_detail="N/A"
  if [[ -n $power_now || -n $voltage_now || -n $current_now ]]; then
    power_detail=""
    if [[ -n $voltage_now ]]; then
      if [[ -n $current_now ]]; then
        power_detail+="$(get_color_with_minimum "$voltage_now" "$voltage_min_design")$(unmicro_int "$voltage_now")V$RESET * $(unmicro_int "$current_now")A = $(unmicro_int "$(($voltage_now * $current_now / 1000000))")W"
      else
        power_detail+="$(get_color_with_minimum "$voltage_now" "$voltage_min_design")$(unmicro_int "$voltage_now")V$RESET"
      fi
    fi
    if [[ -n $power_now ]]; then
    [[ -n $power_detail ]] && power_detail+=", "
      power_detail+="$(unmicro_int "$power_now")W"
    fi
  fi

  # Build output
  local output=""

  if $DETAILED; then
    output="$type $battery ($path):\n"
    output+="  Name: $name\n"
    output+="  Technology: $technology\n"
    output+="  Status: "
    if $COLOR; then
      output+="$(get_status_color "$status")$status$RESET"
    else
      output+="$status"
    fi
  else
    if $COLOR; then
      output="$battery: $(get_status_color "$status")$status$RESET, $(get_progress_color "$capacity")$capacity%$RESET"
    else
      output="$battery: $status, $capacity%"
    fi
  fi

  # Dynamically calculate the static width and progress bar size
  # NOTE: this... probably could be done better????
  local static_width=$(calculate_static_width "$battery" "$status" "$capacity")
  local bar_width=$((WIDTH - static_width))

  # Add progress bar
  if [[ "$TEXT_ONLY" = true ]]; then
    output+=""
  elif [[ $bar_width -gt 0 && $capacity != "N/A" ]]; then
    local progress=$((capacity * bar_width / 100))
    local bar="["
    for ((i = 0; i < bar_width; i++)); do
      local current_percent=$((i * 100 / bar_width))
      if [[ $i -lt $progress ]]; then
        if [[ $COLOR ]]; then
          bar+="$(get_progress_color $current_percent)$(get_progress_background_color $current_percent)#${RESET}"
        else
          bar+="#"
        fi
      else
        bar+=" "
      fi
    done
    bar+="]"
    output+=" $bar"
  else
    output+=" [N/A]"
  fi

  # Add detailed information
  if $DETAILED; then
    output+="\n  Capacity: $(get_progress_color "$capacity")$capacity%$RESET ($capacity_detail)\n"
    output+="  Health: $health_detail\n"
    output+="  Power: $power_detail"
  fi

  echo -e "$output"
}

# Main program(?) starts here

# Find all batteries if none specified
if [[ ${#BATTERIES[@]} -eq 0 ]]; then
  BATTERIES=($(ls /sys/class/power_supply/ | grep BAT))
fi

# Watch mode
if $WATCH; then
  while true; do
    clear
    for battery in "${BATTERIES[@]}"; do
      get_battery_info "$battery"
    done
    sleep 1
  done
else
  for battery in "${BATTERIES[@]}"; do
    get_battery_info "$battery"
  done
fi
