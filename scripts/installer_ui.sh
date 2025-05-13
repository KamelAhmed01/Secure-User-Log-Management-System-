#!/bin/bash

# --- Enhanced UI Components for Installer ---

# Modern color palette
export BOLD="\e[1m"
export DIM="\e[2m"
export ITALIC="\e[3m"
export UNDERLINE="\e[4m"
export BLINK="\e[5m"
export REVERSE="\e[7m"
export HIDDEN="\e[8m"
export RESET="\e[0m"

# Basic colors
export RED="\e[31m"
export GREEN="\e[32m"
export YELLOW="\e[33m"
export BLUE="\e[34m"
export MAGENTA="\e[35m"
export CYAN="\e[36m"
export WHITE="\e[37m"

# Bright colors
export BRIGHT_BLACK="\e[90m"
export BRIGHT_RED="\e[91m"
export BRIGHT_GREEN="\e[92m"
export BRIGHT_YELLOW="\e[93m"
export BRIGHT_BLUE="\e[94m"
export BRIGHT_MAGENTA="\e[95m"
export BRIGHT_CYAN="\e[96m"
export BRIGHT_WHITE="\e[97m"

# Function to show fancy header
show_header() {
    clear
    echo -e "${CYAN}"
    echo -e " ███████╗███████╗ ██████╗██╗   ██╗██████╗ ███████╗    ██╗      ██████╗  ██████╗ ███████╗"
    echo -e " ██╔════╝██╔════╝██╔════╝██║   ██║██╔══██╗██╔════╝    ██║     ██╔═══██╗██╔════╝ ██╔════╝"
    echo -e " ███████╗█████╗  ██║     ██║   ██║██████╔╝█████╗      ██║     ██║   ██║██║  ███╗███████╗"
    echo -e " ╚════██║██╔══╝  ██║     ██║   ██║██╔══██╗██╔══╝      ██║     ██║   ██║██║   ██║╚════██║"
    echo -e " ███████║███████╗╚██████╗╚██████╔╝██║  ██║███████╗    ███████╗╚██████╔╝╚██████╔╝███████║"
    echo -e " ╚══════╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝    ╚══════╝ ╚═════╝  ╚═════╝ ╚══════╝"
    echo -e "${BRIGHT_BLUE}                                                                               v1.0.0"
    echo -e "${RESET}${BOLD}${BRIGHT_WHITE}                  SECURE USER & LOG MANAGEMENT SYSTEM${RESET}"
    echo -e "${DIM}                           Installation Wizard${RESET}"
    echo
    echo -e "${BRIGHT_BLACK}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo
}

# Modern spinner animation
show_spinner() {
    local pid=$1
    local message="$2"
    local spinstr='⣾⣽⣻⢿⡿⣟⣯⣷'
    local delay=0.1
    
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

# Progress bar
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))
    
    printf "${BRIGHT_BLACK}[${RESET}"
    printf "%${filled}s" "" | tr ' ' '█'
    printf "%${empty}s" "" | tr ' ' '░'
    printf "${BRIGHT_BLACK}]${RESET} ${BRIGHT_WHITE}%d%%${RESET}" "$percentage"
    printf "\r"
}

# Section headers
show_section() {
    echo
    echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e " ${MAGENTA}${BOLD}$1${RESET}"
    echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

# Status messages
info() {
    echo -e "${CYAN}▹ ${RESET}${1}"
}

success() {
    echo -e "${BRIGHT_GREEN}✓ ${RESET}${1}"
}

warning() {
    echo -e "${BRIGHT_YELLOW}⚠ ${RESET}${1}"
}

error() {
    echo -e "${BRIGHT_RED}✗ ${RESET}${1}" >&2
}

# Interactive prompt
prompt() {
    echo -ne "${BRIGHT_MAGENTA}? ${RESET}${1}${RESET}"
}

# Loading bar with message
show_loading_bar() {
    local duration=$1
    local message="$2"
    local width=50
    local increment=$((duration * 10))
    
    echo -ne "${CYAN}▹ ${RESET}${message}\n"
    
    for ((i=1; i<=width; i++)); do
        printf "${BRIGHT_BLACK}[${RESET}"
        printf "%${i}s" "" | tr ' ' '█'
        printf "%$((width-i))s" "" | tr ' ' '░'
        printf "${BRIGHT_BLACK}]${RESET} ${BRIGHT_WHITE}%d%%${RESET}" $((i*100/width))
        sleep $(bc -l <<< "scale=3; $duration/$width")
        printf "\r"
    done
    printf "\n${BRIGHT_GREEN}✓ ${RESET}${message} complete\n"
}