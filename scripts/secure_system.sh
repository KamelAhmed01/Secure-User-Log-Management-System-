#!/bin/bash

# Secure System Main Interface Script (Enhanced UI)
# Provides a menu-driven interface to access various system functions.

# Get the directory where the script is located
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# Source configuration and other scripts
CONFIG_FILE="$SCRIPT_DIR/config.sh"
USER_MGMT_SCRIPT="$SCRIPT_DIR/user_management.sh"
LOG_ANALYSIS_SCRIPT="$SCRIPT_DIR/log_analysis.sh"
ASCII_ART_FILE="$SCRIPT_DIR/../ascii_art.txt" # Path to ASCII art
LOADING_ANIMATION_SCRIPT="$SCRIPT_DIR/loading_animation.sh"

# --- Color Definitions ---
RED="\e[0;31m"
GREEN="\e[0;32m"
YELLOW="\e[0;33m"
BLUE="\e[0;34m"
MAGENTA="\e[0;35m"
CYAN="\e[0;36m"
WHITE="\e[0;37m"
BOLD="\e[1m"
UNDERLINE="\e[4m"
NC="\e[0m" # No Color

# Check if running as root, as many operations require it
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${YELLOW}Warning:${NC} This script needs to be run as root or with sudo privileges for most operations." >&2
    fi
}

# Load configuration
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo -e "${RED}Critical Error:${NC} Configuration file ${CYAN}$CONFIG_FILE${NC} not found." >&2
    echo -e "Please ensure the system is installed correctly or run the install.sh script." >&2
    exit 1
fi

# Check for dependent scripts
if [ ! -f "$USER_MGMT_SCRIPT" ]; then
    echo -e "${RED}Critical Error:${NC} User management script ${CYAN}$USER_MGMT_SCRIPT${NC} not found." >&2
    exit 1
fi
if [ ! -f "$LOG_ANALYSIS_SCRIPT" ]; then
    echo -e "${RED}Critical Error:${NC} Log analysis script ${CYAN}$LOG_ANALYSIS_SCRIPT${NC} not found." >&2
    exit 1
fi
if [ ! -f "$LOADING_ANIMATION_SCRIPT" ]; then
    echo -e "${RED}Critical Error:${NC} Loading animation script ${CYAN}$LOADING_ANIMATION_SCRIPT${NC} not found." >&2
    exit 1
fi

# Source the user management and loading animation scripts
source "$USER_MGMT_SCRIPT"
source "$LOADING_ANIMATION_SCRIPT"

# --- Helper Functions ---
pause_and_continue() {
    echo -e "\n${YELLOW}Press Enter to continue...${NC}"
    read -r
}

# --- Display Menus ---

show_main_menu() {
    clear
    if [ -f "$ASCII_ART_FILE" ]; then
        cat "$ASCII_ART_FILE"
    fi
    echo -e "\n${BLUE}${BOLD}===============================================${NC}"
    echo -e " ${MAGENTA}${BOLD}Secure User & Log Management System${NC}"
    echo -e "${BLUE}${BOLD}===============================================${NC}"
    echo -e " ${CYAN} (Enhanced Interface)${NC}"
    echo -e "${BLUE}-----------------------------------------------${NC}"
    echo -e " ${WHITE}1.${NC} ${GREEN}User Management${NC}"
    echo -e " ${WHITE}2.${NC} ${GREEN}Log Analysis & Reporting${NC}"
    echo -e " ${WHITE}3.${NC} ${GREEN}Secure FTP Server Status${NC}"
    echo -e " ${WHITE}4.${NC} ${GREEN}View System Configuration${NC}"
    echo -e " ${WHITE}0.${NC} ${RED}Exit${NC}"
    echo -e "${BLUE}-----------------------------------------------${NC}"
    read -r -p "Enter your choice [0-4]: " main_choice
    handle_main_menu "$main_choice"
}

show_user_management_menu() {
    clear
    echo -e "${BLUE}${BOLD}-----------------------------------------------${NC}"
    echo -e " ${MAGENTA}${BOLD} User Management Menu ${NC}"
    echo -e "${BLUE}${BOLD}-----------------------------------------------${NC}"
    echo -e " ${WHITE}1.${NC} ${CYAN}Create New User${NC}"
    echo -e " ${WHITE}2.${NC} ${CYAN}Delete Existing User${NC}"
    echo -e " ${WHITE}3.${NC} ${CYAN}Modify Existing User${NC}"
    echo -e " ${WHITE}4.${NC} ${CYAN}List Users${NC}"
    echo -e " ${WHITE}9.${NC} ${YELLOW}Back to Main Menu${NC}"
    echo -e " ${WHITE}0.${NC} ${RED}Exit${NC}"
    echo -e "${BLUE}-----------------------------------------------${NC}"
    read -r -p "Enter your choice [0-4, 9]: " um_choice
    handle_user_management_menu "$um_choice"
}

show_log_analysis_menu() {
    clear
    echo -e "${BLUE}${BOLD}-----------------------------------------------${NC}"
    echo -e " ${MAGENTA}${BOLD} Log Analysis & Reporting Menu ${NC}"
    echo -e "${BLUE}${BOLD}-----------------------------------------------${NC}"
    echo -e " ${WHITE}1.${NC} ${CYAN}Generate Daily Failed Login Report (Now)${NC}"
    echo -e " ${WHITE}2.${NC} ${CYAN}View Latest Failed Login Report${NC}"
    echo -e " ${WHITE}9.${NC} ${YELLOW}Back to Main Menu${NC}"
    echo -e " ${WHITE}0.${NC} ${RED}Exit${NC}"
    echo -e "${BLUE}-----------------------------------------------${NC}"
    read -r -p "Enter your choice [0-2, 9]: " la_choice
    handle_log_analysis_menu "$la_choice"
}

# --- Handle Menu Choices ---

handle_main_menu() {
    case "$1" in
        1) show_user_management_menu ;; 
        2) show_log_analysis_menu ;; 
        3) 
            clear
            echo -e "${CYAN}Checking Secure FTP Server (vsftpd) status...${NC}"
            if command -v systemctl &> /dev/null; then
                if systemctl is-active --quiet vsftpd; then
                    echo -e "${GREEN}vsftpd service is active (running).${NC}"
                    sudo systemctl status vsftpd --no-pager
                else
                    echo -e "${YELLOW}vsftpd service is not active.${NC}"
                    read -r -p "Do you want to attempt to start it? (y/n): " start_ftp
                    if [[ "$start_ftp" == "y" || "$start_ftp" == "Y" ]]; then
                        echo -e "${CYAN}Attempting to start vsftpd...${NC}"
                        sudo systemctl start vsftpd &
                        local pid=$!
                        show_loading_animation $pid
                        wait $pid
                        if systemctl is-active --quiet vsftpd; then
                            echo -e "${GREEN}vsftpd service started successfully.${NC}"
                        else
                            echo -e "${RED}Failed to start vsftpd.${NC} Check logs: ${CYAN}sudo journalctl -u vsftpd${NC} or ${CYAN}/var/log/vsftpd.log${NC}"
                        fi
                    fi
                fi
            else
                echo -e "${YELLOW}systemctl command not found. Cannot check vsftpd status automatically.${NC}"
                echo -e "Please check manually, e.g., using ${CYAN}\'ps aux | grep vsftpd\'${NC} or service status commands."
            fi
            pause_and_continue
            show_main_menu
            ;; 
        4) 
            clear
            echo -e "${BLUE}--- ${BOLD}System Configuration Overview${NC} (from ${CYAN}$CONFIG_FILE${NC}) ---${NC}"
            if [ -f "$CONFIG_FILE" ]; then
                cat "$CONFIG_FILE"
            else
                echo -e "${RED}Error:${NC} Configuration file ${CYAN}$CONFIG_FILE${NC} not found."
            fi
            echo -e "${BLUE}--- End of Configuration ---${NC}"
            pause_and_continue
            show_main_menu
            ;; 
        0) echo -e "${MAGENTA}Exiting Secure System Management. Goodbye!${NC}"; exit 0 ;; 
        *) echo -e "${RED}Invalid choice. Please try again.${NC}"; sleep 1; show_main_menu ;; 
    esac
}

handle_user_management_menu() {
    # Functions like create_new_user are sourced from user_management.sh
    case "$1" in
        1) create_new_user ;; # Assuming create_new_user handles its own output/loading if needed
        2) delete_existing_user ;; # Assuming delete_existing_user handles its own output/loading if needed
        3) modify_existing_user ;; # Assuming modify_existing_user handles its own output/loading if needed
        4) list_existing_users ;; 
        9) show_main_menu ;; 
        0) echo -e "${MAGENTA}Exiting Secure System Management. Goodbye!${NC}"; exit 0 ;; 
        *) echo -e "${RED}Invalid choice. Please try again.${NC}"; sleep 1; show_user_management_menu ;; 
    esac
    # After action (if not exit or back to main), pause and return to user menu
    if [[ "$1" -ge 1 && "$1" -le 4 ]]; then
        pause_and_continue
    fi
    # Loop back to user menu unless exited or explicitly returned to main menu
    if [[ "$1" != "9" && "$1" != "0" ]]; then
      show_user_management_menu
    fi
}

handle_log_analysis_menu() {
    case "$1" in
        1) 
            clear
            echo -e "${CYAN}Generating daily failed login report now...${NC}"
            if [ -x "$LOG_ANALYSIS_SCRIPT" ]; then
                sudo "$LOG_ANALYSIS_SCRIPT" &
                local pid=$!
                show_loading_animation $pid
                wait $pid # Wait for the script to complete
                echo -e "${GREEN}Log analysis script execution finished.${NC} Report should be in ${CYAN}$SECURITY_REPORT_DIR${NC}"
            else
                echo -e "${RED}Error:${NC} Log analysis script ${CYAN}$LOG_ANALYSIS_SCRIPT${NC} is not executable or not found." >&2
                echo -e "Please ensure it exists and run: ${CYAN}sudo chmod +x $LOG_ANALYSIS_SCRIPT${NC}"
            fi
            ;;
        2) 
            clear
            echo -e "${CYAN}Displaying the latest failed login report...${NC}"
            latest_report=$(ls -1t "$SECURITY_REPORT_DIR"/failed_logins_report_*.txt 2>/dev/null | head -n 1)
            if [ -n "$latest_report" ] && [ -f "$latest_report" ]; then
                echo -e "${GREEN}Latest report:${NC} ${CYAN}$latest_report${NC}"
                echo -e "${BLUE}--- Report Content ---${NC}"
                cat "$latest_report"
                echo -e "${BLUE}--- End of Report ---${NC}"
            else 
                echo -e "${YELLOW}No reports found in ${CYAN}$SECURITY_REPORT_DIR${NC} (expected: ${CYAN}$SECURITY_REPORT_DIR/failed_logins_report_YYYY-MM-DD.txt${NC})."
                echo -e "You might need to generate one first (Option 1)."
            fi
            ;;
        9) show_main_menu ;; 
        0) echo -e "${MAGENTA}Exiting Secure System Management. Goodbye!${NC}"; exit 0 ;; 
        *) echo -e "${RED}Invalid choice. Please try again.${NC}"; sleep 1; show_log_analysis_menu ;; 
    esac
    if [[ "$1" -ge 1 && "$1" -le 2 ]]; then
        pause_and_continue
    fi
    if [[ "$1" != "9" && "$1" != "0" ]]; then
      show_log_analysis_menu
    fi
}

# --- Main Script Execution ---
check_root
show_main_menu

exit 0

