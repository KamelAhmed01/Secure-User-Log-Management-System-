#!/bin/bash

# Enhanced loading animation script

# Source color definitions if available
source "$(dirname "$(readlink -f "$0")")/colors.sh" 2>/dev/null || {
    # Fallback color definitions if colors.sh isn't found
    BOLD="\e[1m"
    DIM="\e[2m"
    RESET="\e[0m"
    CYAN="\e[36m"
    BRIGHT_CYAN="\e[96m"
    BRIGHT_GREEN="\e[92m"
    BRIGHT_WHITE="\e[97m"
    GRAY="\e[90m"
}

# Function to display a loading animation with modern spinner
show_loading_animation() {
    local pid=$1
    local message="${2:-Processing}"
    local delay=0.1
    local spinstr='⣾⣽⣻⢿⡿⣟⣯⣷'
    
    echo -ne "${CYAN}▹ ${RESET}${message} "
    
    while [ "$(ps a | awk '{print $1}' | grep -w $pid)" ]; do
        local temp=${spinstr#?}
        printf "${BRIGHT_CYAN}%c${RESET}" "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b"
    done
    
    printf " ${BRIGHT_GREEN}✓${RESET}\n"
}

# Progress bar for operations with known progress
show_progress_bar() {
    local percent=$1
    local width=50
    local num_filled=$(($width * $percent / 100))
    local num_empty=$(($width - $num_filled))
    
    printf "${GRAY}[${RESET}"
    printf "%${num_filled}s" "" | tr ' ' '█'
    printf "%${num_empty}s" "" | tr ' ' '░'
    printf "${GRAY}]${RESET} ${BRIGHT_WHITE}%d%%${RESET}" $percent
    printf "\r"
}

