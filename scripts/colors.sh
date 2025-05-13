#!/bin/bash

# Terminal Colors and Styling definitions
# Source this file in other scripts to use consistent styling

# Text styling
BOLD="\e[1m"
DIM="\e[2m"
ITALIC="\e[3m"
UNDERLINE="\e[4m"
BLINK="\e[5m"
REVERSE="\e[7m"
HIDDEN="\e[8m"
RESET="\e[0m"

# Foreground colors
BLACK="\e[30m"
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
MAGENTA="\e[35m"
CYAN="\e[36m"
WHITE="\e[37m"
GRAY="\e[90m"
BRIGHT_RED="\e[91m"
BRIGHT_GREEN="\e[92m"
BRIGHT_YELLOW="\e[93m"
BRIGHT_BLUE="\e[94m"
BRIGHT_MAGENTA="\e[95m"
BRIGHT_CYAN="\e[96m"
BRIGHT_WHITE="\e[97m"

# Background colors
BG_BLACK="\e[40m"
BG_RED="\e[41m"
BG_GREEN="\e[42m"
BG_YELLOW="\e[43m"
BG_BLUE="\e[44m"
BG_MAGENTA="\e[45m"
BG_CYAN="\e[46m"
BG_WHITE="\e[47m"

# Common formatting functions
echo_info() {
    echo -e "${GREEN}[${BOLD}INFO${RESET}${GREEN}]${RESET} $1"
}

echo_warn() {
    echo -e "${YELLOW}[${BOLD}WARN${RESET}${YELLOW}]${RESET} $1"
}

echo_error() {
    echo -e "${RED}[${BOLD}ERROR${RESET}${RED}]${RESET} $1" >&2
}

echo_success() {
    echo -e "${BRIGHT_GREEN}[${BOLD}SUCCESS${RESET}${BRIGHT_GREEN}]${RESET} $1"
}

# Divider line
divider() {
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

# Section header
show_section_header() {
    echo
    echo -e "${YELLOW}${BOLD}[ ${1} ]${RESET}"
    divider
}