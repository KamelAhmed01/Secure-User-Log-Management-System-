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

# Source colors if available, otherwise define them
if [ -f "$SCRIPT_DIR/colors.sh" ]; then
    source "$SCRIPT_DIR/colors.sh"
else
    # --- Enhanced Color Definitions ---
    BOLD="\e[1m"
    DIM="\e[2m"
    ITALIC="\e[3m"
    UNDERLINE="\e[4m"
    RESET="\e[0m"
    
    # Basic colors
    RED="\e[31m"
    GREEN="\e[32m"
    YELLOW="\e[33m"
    BLUE="\e[34m"
    MAGENTA="\e[35m"
    CYAN="\e[36m"
    WHITE="\e[37m"
    
    # Bright colors
    GRAY="\e[90m"
    BRIGHT_RED="\e[91m"
    BRIGHT_GREEN="\e[92m"
    BRIGHT_YELLOW="\e[93m"
    BRIGHT_BLUE="\e[94m"
    BRIGHT_MAGENTA="\e[95m"
    BRIGHT_CYAN="\e[96m"
    BRIGHT_WHITE="\e[97m"
    
    # Shortcuts for legacy code compatibility
    NC="$RESET"
fi

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
    echo -e "\n${BRIGHT_YELLOW}Press Enter to continue...${RESET}"
    read -r
}

# Custom logo function if the ASCII art file is missing
show_logo() {
    if [ -f "$ASCII_ART_FILE" ]; then
        # Use the colors to enhance the ASCII art file display
        echo -e "${CYAN}"
        cat "$ASCII_ART_FILE"
        echo -e "${BRIGHT_BLUE}                                                                               v1.0.0"
        echo -e "${RESET}${BOLD}${BRIGHT_WHITE}                  SECURE USER & LOG MANAGEMENT SYSTEM${RESET}"
        echo -e "${DIM}                           System Interface${RESET}"
        echo
        echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
        echo
    else
        # Fallback to embedded logo if the file is missing
        echo -e "${CYAN}"
        echo -e " ███████╗███████╗ ██████╗██╗   ██╗██████╗ ███████╗    ██╗      ██████╗  ██████╗ ███████╗"
        echo -e " ██╔════╝██╔════╝██╔════╝██║   ██║██╔══██╗██╔════╝    ██║     ██╔═══██╗██╔════╝ ██╔════╝"
        echo -e " ███████╗█████╗  ██║     ██║   ██║██████╔╝█████╗      ██║     ██║   ██║██║  ███╗███████╗"
        echo -e " ╚════██║██╔══╝  ██║     ██║   ██║██╔══██╗██╔══╝      ██║     ██║   ██║██║   ██║╚════██║"
        echo -e " ███████║███████╗╚██████╗╚██████╔╝██║  ██║███████╗    ███████╗╚██████╔╝╚██████╔╝███████║"
        echo -e " ╚══════╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝    ╚══════╝ ╚═════╝  ╚═════╝ ╚══════╝"
        echo -e "${BRIGHT_BLUE}                                                                               v1.0.0"
        echo -e "${RESET}${BOLD}${BRIGHT_WHITE}                  SECURE USER & LOG MANAGEMENT SYSTEM${RESET}"
        echo -e "${DIM}                           System Interface${RESET}"
        echo
        echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
        echo
    fi
}

# --- Display Menus ---

show_main_menu() {
    clear
    show_logo
    echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e " ${MAGENTA}${BOLD}Secure User & Log Management System${RESET}"
    echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e " ${CYAN} (Enhanced Interface)${RESET}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e " ${WHITE}1.${RESET} ${BRIGHT_GREEN}User Management${RESET}"
    echo -e " ${WHITE}2.${RESET} ${BRIGHT_GREEN}Log Analysis & Reporting${RESET}"
    echo -e " ${WHITE}3.${RESET} ${BRIGHT_GREEN}Secure FTP Server Status${RESET}"
    echo -e " ${WHITE}4.${RESET} ${BRIGHT_GREEN}View System Configuration${RESET}"
    echo -e " ${WHITE}0.${RESET} ${BRIGHT_RED}Exit${RESET}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    read -r -p "$(echo -e "${CYAN}▸${RESET} Enter your choice [0-4]: ")" main_choice
    handle_main_menu "$main_choice"
}

show_user_management_menu() {
    clear
    echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e " ${MAGENTA}${BOLD}User Management Menu${RESET}"
    echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e " ${WHITE}1.${RESET} ${BRIGHT_CYAN}Create New User${RESET}"
    echo -e " ${WHITE}2.${RESET} ${BRIGHT_CYAN}Delete Existing User${RESET}"
    echo -e " ${WHITE}3.${RESET} ${BRIGHT_CYAN}Modify Existing User${RESET}"
    echo -e " ${WHITE}4.${RESET} ${BRIGHT_CYAN}List Users${RESET}"
    echo -e " ${WHITE}9.${RESET} ${BRIGHT_YELLOW}Back to Main Menu${RESET}"
    echo -e " ${WHITE}0.${RESET} ${BRIGHT_RED}Exit${RESET}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    read -r -p "$(echo -e "${CYAN}▸${RESET} Enter your choice [0-4, 9]: ")" um_choice
    handle_user_management_menu "$um_choice"
}

show_log_analysis_menu() {
    clear
    echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e " ${MAGENTA}${BOLD}Log Analysis & Reporting Menu${RESET}"
    echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e " ${WHITE}1.${RESET} ${BRIGHT_CYAN}Generate Daily Failed Login Report (Now)${RESET}"
    echo -e " ${WHITE}2.${RESET} ${BRIGHT_CYAN}View Latest Failed Login Report${RESET}"
    echo -e " ${WHITE}9.${RESET} ${BRIGHT_YELLOW}Back to Main Menu${RESET}"
    echo -e " ${WHITE}0.${RESET} ${BRIGHT_RED}Exit${RESET}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    read -r -p "$(echo -e "${CYAN}▸${RESET} Enter your choice [0-2, 9]: ")" la_choice
    handle_log_analysis_menu "$la_choice"
}

# --- Handle Menu Choices (with updated UI elements) ---

handle_main_menu() {
    case "$1" in
        1) show_user_management_menu ;; 
        2) show_log_analysis_menu ;; 
        3) 
            clear
            echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
            echo -e " ${MAGENTA}${BOLD}Secure FTP Server Status${RESET}"
            echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
            echo -e "${CYAN}▹ ${RESET}Checking Secure FTP Server (vsftpd) status..."
            if command -v systemctl &> /dev/null; then
                if systemctl is-active --quiet vsftpd; then
                    echo -e "${BRIGHT_GREEN}✓ vsftpd service is active (running).${RESET}"
                    sudo systemctl status vsftpd --no-pager
                else
                    echo -e "${BRIGHT_YELLOW}⚠ vsftpd service is not active.${RESET}"
                    read -r -p "$(echo -e "${CYAN}▸${RESET} Do you want to attempt to start it? (y/n): ")" start_ftp
                    if [[ "$start_ftp" == "y" || "$start_ftp" == "Y" ]]; then
                        echo -e "${CYAN}▹ ${RESET}Attempting to start vsftpd..."
                        
                        # Add troubleshooting steps before attempting to start
                        echo -e "${CYAN}▹ ${RESET}Performing pre-start validation checks..."
                        
                        # Check if vsftpd is installed
                        if ! command -v vsftpd &> /dev/null; then
                            echo -e "${BRIGHT_RED}✗ Error: vsftpd is not installed.${RESET}"
                            echo -e "Please install it with: ${BRIGHT_CYAN}sudo apt update && sudo apt install vsftpd${RESET}"
                            pause_and_continue
                            show_main_menu
                            continue
                        fi
                        
                        # Check config file existence
                        if [ ! -f "/etc/vsftpd.conf" ]; then
                            echo -e "${BRIGHT_RED}✗ Error: /etc/vsftpd.conf is missing.${RESET}"
                            echo -e "Please run the installer again or manually create the config file."
                            pause_and_continue
                            show_main_menu
                            continue
                        fi
                        
                        # Get certificate file paths from config
                        cert_file=$(grep -oP '^rsa_cert_file=\K.*' /etc/vsftpd.conf)
                        key_file=$(grep -oP '^rsa_private_key_file=\K.*' /etc/vsftpd.conf)
                        
                        # Check certificate files
                        if [ ! -f "$cert_file" ] || [ ! -f "$key_file" ]; then
                            echo -e "${BRIGHT_YELLOW}⚠ Warning: SSL certificate files are missing or inaccessible.${RESET}"
                            echo -e "Certificate path: ${BRIGHT_CYAN}$cert_file${RESET}"
                            echo -e "Key path: ${BRIGHT_CYAN}$key_file${RESET}"
                            
                            if ask_yes_no "Do you want to regenerate the SSL certificate?" "y"; then
                                mkdir -p "$(dirname "$cert_file")" 2>/dev/null
                                
                                # Generate a new self-signed certificate
                                echo -e "${CYAN}▹ ${RESET}Generating new SSL certificate..."
                                sudo openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
                                    -keyout "$key_file" -out "$cert_file" \
                                    -subj "/C=XX/ST=State/L=City/O=Organization/CN=localhost" 2>/dev/null &
                                local pid=$!
                                show_loading_animation $pid "Generating SSL certificate"
                                
                                if [ $? -eq 0 ]; then
                                    sudo chmod 600 "$key_file" "$cert_file" 2>/dev/null
                                    echo -e "${BRIGHT_GREEN}✓ SSL certificate regenerated successfully.${RESET}"
                                else
                                    echo -e "${BRIGHT_RED}✗ Failed to generate SSL certificate.${RESET}"
                                fi
                            fi
                        fi
                        
                        # Ensure empty directory exists
                        if [ ! -d "/var/run/vsftpd/empty" ]; then
                            echo -e "${BRIGHT_YELLOW}⚠ Creating missing directory: /var/run/vsftpd/empty${RESET}"
                            sudo mkdir -p /var/run/vsftpd/empty
                        fi
                        
                        # Now attempt to start the service
                        sudo systemctl start vsftpd &
                        local pid=$!
                        show_loading_animation $pid "Starting vsftpd service"
                        
                        if systemctl is-active --quiet vsftpd; then
                            echo -e "${BRIGHT_GREEN}✓ vsftpd service started successfully.${RESET}"
                        else
                            echo -e "${BRIGHT_RED}✗ Failed to start vsftpd.${RESET} Check logs: ${BRIGHT_CYAN}sudo journalctl -u vsftpd${RESET} or ${BRIGHT_CYAN}/var/log/vsftpd.log${RESET}"
                            
                            # Additional diagnostics
                            echo -e "\n${BRIGHT_CYAN}▹ Diagnostic information:${RESET}"
                            echo -e "${BRIGHT_YELLOW}1. Check systemd service status:${RESET}"
                            sudo systemctl status vsftpd --no-pager
                            
                            echo -e "\n${BRIGHT_YELLOW}2. Common issues and solutions:${RESET}"
                            echo -e "   - SSL certificate paths may be incorrect in /etc/vsftpd.conf"
                            echo -e "   - Port 21 may be in use by another service"
                            echo -e "   - Firewall may be blocking FTP ports (20, 21)"
                            echo -e "   - SELinux/AppArmor may be restricting vsftpd"
                            
                            if ask_yes_no "Would you like to try the basic configuration fix?" "y"; then
                                echo -e "${CYAN}▹ ${RESET}Attempting configuration fix..."
                                
                                # Backup existing config if it exists
                                if [ -f "/vsftpd.conf" ]; then
                                    echo -e "${CYAN}▹ ${RESET}Backing up existing configuration..."
                                    sudo mv /vsftpd.conf /vsftpd.conf.bak
                                    if [ $? -eq 0 ]; then
                                        echo -e "${BRIGHT_GREEN}✓ Backup created: /vsftpd.conf.bak${RESET}"
                                    else
                                        echo -e "${BRIGHT_RED}✗ Failed to create backup${RESET}"
                                        return 1
                                    fi
                                fi
                                
                                # Create minimal config
                                echo -e "${CYAN}▹ ${RESET}Creating minimal configuration..."
                                echo "listen=YES" | sudo tee /vsftpd.conf > /dev/null
                                if [ $? -eq 0 ]; then
                                    echo -e "${BRIGHT_GREEN}✓ Basic configuration created${RESET}"
                                else
                                    echo -e "${BRIGHT_RED}✗ Failed to create configuration${RESET}"
                                    return 1
                                fi
                                
                                # Restart service
                                echo -e "${CYAN}▹ ${RESET}Restarting vsftpd service..."
                                sudo systemctl restart vsftpd
                                if systemctl is-active --quiet vsftpd; then
                                    echo -e "${BRIGHT_GREEN}✓ vsftpd service started successfully with basic configuration${RESET}"
                                else
                                    echo -e "${BRIGHT_RED}✗ Service still failing after basic configuration${RESET}"
                                fi
                            fi
                            
                            if ask_yes_no "View recent vsftpd logs?" "y"; then
                                sudo journalctl -u vsftpd --no-pager -n 20
                            fi
                        fi
                    fi
                fi
            else
                echo -e "${BRIGHT_YELLOW}⚠ systemctl command not found. Cannot check vsftpd status automatically.${RESET}"
                echo -e "Please check manually, e.g., using ${BRIGHT_CYAN}\'ps aux | grep vsftpd\'${RESET} or service status commands."
            fi
            pause_and_continue
            show_main_menu
            ;; 
        4) 
            clear
            echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
            echo -e " ${MAGENTA}${BOLD}System Configuration Overview${RESET}"
            echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
            
            if [ -f "$CONFIG_FILE" ]; then
                echo -e "${GRAY}# Config file: ${BRIGHT_CYAN}$CONFIG_FILE${RESET}"
                echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
                cat "$CONFIG_FILE"
                echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
            else
                echo -e "${BRIGHT_RED}✗ Error:${RESET} Configuration file ${BRIGHT_CYAN}$CONFIG_FILE${RESET} not found."
            fi
            
            pause_and_continue
            show_main_menu
            ;; 
        0) echo -e "${BRIGHT_MAGENTA}Exiting Secure System Management. Goodbye!${RESET}"; exit 0 ;; 
        *) echo -e "${BRIGHT_RED}✗ Invalid choice. Please try again.${RESET}"; sleep 1; show_main_menu ;; 
    esac
}

handle_user_management_menu() {
    # Functions like create_new_user are sourced from user_management.sh
    case "$1" in
        1) clear; echo -e "${CYAN}▹ ${RESET}${BOLD}Creating New User${RESET}\n"; create_new_user ;; 
        2) clear; echo -e "${CYAN}▹ ${RESET}${BOLD}Deleting Existing User${RESET}\n"; delete_existing_user ;; 
        3) clear; echo -e "${CYAN}▹ ${RESET}${BOLD}Modifying Existing User${RESET}\n"; modify_existing_user ;; 
        4) clear; echo -e "${CYAN}▹ ${RESET}${BOLD}Listing Users${RESET}\n"; list_existing_users ;; 
        9) show_main_menu ;; 
        0) echo -e "${BRIGHT_MAGENTA}Exiting Secure System Management. Goodbye!${RESET}"; exit 0 ;; 
        *) echo -e "${BRIGHT_RED}✗ Invalid choice. Please try again.${RESET}"; sleep 1; show_user_management_menu ;; 
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
            echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
            echo -e " ${MAGENTA}${BOLD}Generating Daily Failed Login Report${RESET}"
            echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
            echo -e "${CYAN}▹ ${RESET}${BOLD}Starting log analysis process...${RESET}"
            
            if [ -x "$LOG_ANALYSIS_SCRIPT" ]; then
                sudo "$LOG_ANALYSIS_SCRIPT" &
                local pid=$!
                show_loading_animation $pid "Analyzing log files"
                echo -e "${BRIGHT_GREEN}✓ Log analysis complete.${RESET} Report saved to: ${BRIGHT_CYAN}$SECURITY_REPORT_DIR${RESET}"
            else
                echo -e "${BRIGHT_RED}✗ Error:${RESET} Log analysis script ${BRIGHT_CYAN}$LOG_ANALYSIS_SCRIPT${RESET} is not executable or not found." >&2
                echo -e "Please ensure it exists and run: ${BRIGHT_CYAN}sudo chmod +x $LOG_ANALYSIS_SCRIPT${RESET}"
            fi
            ;;
        2) 
            clear
            echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
            echo -e " ${MAGENTA}${BOLD}Viewing Latest Failed Login Report${RESET}"
            echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
            echo -e "${CYAN}▹ ${RESET}Searching for the latest report..."
            
            latest_report=$(ls -1t "$SECURITY_REPORT_DIR"/failed_logins_report_*.txt 2>/dev/null | head -n 1)
            if [ -n "$latest_report" ] && [ -f "$latest_report" ]; then
                echo -e "${BRIGHT_GREEN}✓ Found:${RESET} ${BRIGHT_CYAN}$latest_report${RESET}"
                echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
                cat "$latest_report"
                echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
            else 
                echo -e "${BRIGHT_YELLOW}⚠ No reports found${RESET} in ${BRIGHT_CYAN}$SECURITY_REPORT_DIR${RESET}"
                echo -e "Expected file pattern: ${BRIGHT_CYAN}$SECURITY_REPORT_DIR/failed_logins_report_YYYY-MM-DD.txt${RESET}"
                echo -e "You might need to generate one first (Option 1)."
            fi
            ;;
        9) show_main_menu ;; 
        0) echo -e "${BRIGHT_MAGENTA}Exiting Secure System Management. Goodbye!${RESET}"; exit 0 ;; 
        *) echo -e "${BRIGHT_RED}✗ Invalid choice. Please try again.${RESET}"; sleep 1; show_log_analysis_menu ;; 
    esac
    if [[ "$1" -ge 1 && "$1" -le 2 ]]; then
        pause_and_continue
    fi
    if [[ "$1" != "9" && "$1" != "0" ]]; then
      show_log_analysis_menu
    fi
}

# Helper function for yes/no questions (for FTP section)
ask_yes_no() {
    local question="$1"
    local default_answer="${2:-n}"
    local prompt
    
    if [ "$default_answer" = "y" ]; then
        prompt="Y/n"
        default="Y"
    else
        prompt="y/N"
        default="N"
    fi
    
    read -r -p "$(echo -e "${CYAN}▸${RESET} $question [$prompt]: ")" answer
    answer=${answer:-$default}
    
    [[ $answer =~ ^[Yy]$ ]]
}

# --- Main Script Execution ---
check_root
show_main_menu

exit 0

