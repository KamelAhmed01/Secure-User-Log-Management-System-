#!/bin/bash
# Secure System Main Interface Script (Core Functionality)
# Provides a menu-driven interface to access various system functions.

# Get the directory where the script is located
SCRIPT_DIR="$(dirname "$0")"

# Source colors and styling
if [ -f "$SCRIPT_DIR/colors.sh" ]; then
    source "$SCRIPT_DIR/colors.sh"
else
    echo "Error: colors.sh not found. Styling will be unavailable." >&2
    # Define minimal styling for critical functionality
    RESET="\e[0m"
    RED="\e[31m"
    BOLD="\e[1m"
fi

# Source configuration and other scripts
CONFIG_FILE="$SCRIPT_DIR/config.sh"
USER_MGMT_SCRIPT="$SCRIPT_DIR/user_management.sh"
LOG_ANALYSIS_SCRIPT="$SCRIPT_DIR/log_analysis.sh"

# Check if running as root, as many operations require it
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo_error "This script needs to be run as root or with sudo privileges for most operations."
        echo -e "${BRIGHT_YELLOW}Tip:${RESET} Try running the script with '${BOLD}sudo $0${RESET}'"
        # For core operations, especially user management and vsftpd control, root is essential.
        # Allow to proceed but functions will likely fail if not root.
        return 1
    fi
    return 0
}

# Spinner animation
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep -w $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Show fancy ASCII art logo
show_logo() {
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
    echo -e "${DIM}                              Management Console${RESET}"
    echo
    divider
    echo
}

# Load configuration
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo_error "Critical Error: Configuration file $CONFIG_FILE not found."
    echo_error "Please ensure the system is installed correctly or run the install.sh script."
    exit 1
fi

# Check for dependent scripts
if [ ! -f "$USER_MGMT_SCRIPT" ]; then
    echo_error "Critical Error: User management script $USER_MGMT_SCRIPT not found."
    exit 1
fi
if [ ! -f "$LOG_ANALYSIS_SCRIPT" ]; then
    echo_error "Critical Error: Log analysis script $LOG_ANALYSIS_SCRIPT not found."
    exit 1
fi

# Source the user management script to make its functions available in this script's scope
source "$USER_MGMT_SCRIPT"

# --- Display Menus ---

show_main_menu() {
    show_logo
    
    # Display system information
    echo -e "${BRIGHT_WHITE}${BOLD}System Information${RESET}"
    echo -e "${CYAN}▸ ${RESET}${BOLD}Current User:${RESET}      ${SUDO_USER:-$(whoami)}"
    echo -e "${CYAN}▸ ${RESET}${BOLD}Hostname:${RESET}          $(hostname)"
    echo -e "${CYAN}▸ ${RESET}${BOLD}Date & Time:${RESET}       $(date '+%Y-%m-%d %H:%M:%S')"
    if check_root > /dev/null; then
        echo -e "${CYAN}▸ ${RESET}${BOLD}Privileges:${RESET}        ${BRIGHT_GREEN}Root/Admin${RESET}"
    else
        echo -e "${CYAN}▸ ${RESET}${BOLD}Privileges:${RESET}        ${YELLOW}Limited (Some functions may not work)${RESET}"
    fi
    echo

    # Menu options
    echo -e "${BRIGHT_WHITE}${BOLD}Main Menu${RESET}"
    divider
    echo -e "  ${BLUE}1.${RESET} ${BOLD}User Management${RESET}             Manage system users, passwords, and accounts"
    echo -e "  ${BLUE}2.${RESET} ${BOLD}Log Analysis & Reporting${RESET}    Generate and view security reports"
    echo -e "  ${BLUE}3.${RESET} ${BOLD}Secure FTP Server Status${RESET}    Check and manage FTP server"
    echo -e "  ${BLUE}4.${RESET} ${BOLD}View System Configuration${RESET}   Review system settings"
    echo -e "  ${RED}0.${RESET} ${BOLD}Exit${RESET}                      Exit the management console"
    divider
    echo
    
    echo -ne "${CYAN}▹ ${RESET}${BOLD}Enter your choice [0-4]:${RESET} "
    read -r main_choice
    handle_main_menu "$main_choice"
}

show_user_management_menu() {
    clear
    echo -e "${CYAN}"
    echo -e " ██╗   ██╗███████╗███████╗██████╗     ███╗   ███╗ █████╗ ███╗   ██╗ █████╗  ██████╗ ███████╗███╗   ███╗███████╗███╗   ██╗████████╗"
    echo -e " ██║   ██║██╔════╝██╔════╝██╔══██╗    ████╗ ████║██╔══██╗████╗  ██║██╔══██╗██╔════╝ ██╔════╝████╗ ████║██╔════╝████╗  ██║╚══██╔══╝"
    echo -e " ██║   ██║███████╗█████╗  ██████╔╝    ██╔████╔██║███████║██╔██╗ ██║███████║██║  ███╗█████╗  ██╔████╔██║█████╗  ██╔██╗ ██║   ██║   "
    echo -e " ██║   ██║╚════██║██╔══╝  ██╔══██╗    ██║╚██╔╝██║██╔══██║██║╚██╗██║██╔══██║██║   ██║██╔══╝  ██║╚██╔╝██║██╔══╝  ██║╚██╗██║   ██║   "
    echo -e " ╚██████╔╝███████║███████╗██║  ██║    ██║ ╚═╝ ██║██║  ██║██║ ╚████║██║  ██║╚██████╔╝███████╗██║ ╚═╝ ██║███████╗██║ ╚████║   ██║   "
    echo -e "  ╚═════╝ ╚══════╝╚══════╝╚═╝  ╚═╝    ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝   ╚═╝   "
    echo -e "${RESET}"
    echo
    echo -e "${BRIGHT_WHITE}${BOLD}User Management Menu${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "  ${BLUE}1.${RESET} ${BOLD}Create New User${RESET}        Add a new system user with secure password"
    echo -e "  ${BLUE}2.${RESET} ${BOLD}Delete Existing User${RESET}   Remove a user from the system"
    echo -e "  ${BLUE}3.${RESET} ${BOLD}Modify Existing User${RESET}   Change password, shell, expiry, or lock/unlock"
    echo -e "  ${BLUE}4.${RESET} ${BOLD}List Users${RESET}             Show all non-system users"
    echo -e "  ${GREEN}9.${RESET} ${BOLD}Back to Main Menu${RESET}     Return to main options"
    echo -e "  ${RED}0.${RESET} ${BOLD}Exit${RESET}                  Exit the management console"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo
    
    echo -ne "${CYAN}▹ ${RESET}${BOLD}Enter your choice [0-4, 9]:${RESET} "
    fi
    read -r um_choice
    handle_user_management_menu "$um_choice"
}# --- Main Script Execution ---

show_log_analysis_menu() {menu
    clear
    echo -e "${CYAN}"exit 0
    echo -e " ██╗      ██████╗  ██████╗      █████╗ ███╗   ██╗ █████╗ ██╗  ██╗   ██╗███████╗██╗███████╗"
    echo -e " ██║     ██╔═══██╗██╔════╝     ██╔══██╗████╗  ██║██╔══██╗██║  ╚██╗ ██╔╝██╔════╝██║██╔════╝"    echo -e " ██║     ██║   ██║██║  ███╗    ███████║██╔██╗ ██║███████║██║   ╚████╔╝ ███████╗██║███████╗"
    echo -e " ██║     ██║   ██║██║   ██║    ██╔══██║██║╚██╗██║██╔══██║██║    ╚██╔╝  ╚════██║██║╚════██║"
    echo -e " ███████╗╚██████╔╝╚██████╔╝    ██║  ██║██║ ╚████║██║  ██║███████╗██║   ███████║██║███████║"
    echo -e " ╚══════╝ ╚═════╝  ╚═════╝     ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝╚══════╝╚═╝   ╚══════╝╚═╝╚══════╝"
    echo -e "${RESET}"
    echo
    
    echo -e "${BRIGHT_WHITE}${BOLD}Log Analysis & Reporting Menu${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "  ${BLUE}1.${RESET} ${BOLD}Generate Daily Report (Now)${RESET}     Analyze logs and create a security report"
    echo -e "  ${BLUE}2.${RESET} ${BOLD}View Latest Failed Login Report${RESET} Display the most recent security report"
    echo -e "  ${GREEN}9.${RESET} ${BOLD}Back to Main Menu${RESET}              Return to main options"
    echo -e "  ${RED}0.${RESET} ${BOLD}Exit${RESET}                           Exit the management console"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo
    
    echo -ne "${CYAN}▹ ${RESET}${BOLD}Enter your choice [0-2, 9]:${RESET} "
    read -r la_choice
    handle_log_analysis_menu "$la_choice"
}

# --- Handle Menu Choices ---

handle_main_menu() {
    case "$1" in
        1) show_user_management_menu ;; 
        2) show_log_analysis_menu ;; 
        3) 
            show_section_header "Secure FTP Server Status"
            echo_info "Checking Secure FTP Server (vsftpd) status..."
            
            if command -v systemctl &> /dev/null; then
                if systemctl is-active --quiet vsftpd; then
                    echo -e "${BRIGHT_GREEN}● ${BOLD}ACTIVE${RESET} - vsftpd service is running\n"
                    systemctl status vsftpd --no-pager | grep -v "^\s*$" | grep -v "^$" | 
                        sed -E "s/.*active \(running\).*/  ${BRIGHT_GREEN}● Active (running)${RESET}/" |
                        sed -E "s/(.*Main PID:.*)/  ${BLUE}\1${RESET}/"
                    echo
                    
                    # Get some vsftpd information if possible
                    local ftp_version=$(vsftpd -v 2>&1 | grep -oP "vsftpd: version \K[0-9.]+")
                    if [ -n "$ftp_version" ]; then
                        echo -e "${BOLD}FTP Server Version:${RESET} $ftp_version"
                    fi
                    
                    local cert_path=$(grep -oP "^rsa_cert_file=\K.*" /etc/vsftpd.conf 2>/dev/null)
                    if [ -n "$cert_path" ] && [ -f "$cert_path" ]; then
                        echo -e "${BOLD}SSL Certificate:${RESET} $cert_path"
                        echo -e "${BOLD}Certificate Details:${RESET}"
                        openssl x509 -in "$cert_path" -noout -subject -dates | 
                            sed -E "s/subject=.*/  ${GREEN}Subject:${RESET} \0/" |
                            sed -E "s/notBefore=.*/  ${GREEN}Valid From:${RESET} \0/" |
                            sed -E "s/notAfter=.*/  ${GREEN}Valid Until:${RESET} \0/"
                    fi
                else
                    echo -e "${RED}● ${BOLD}INACTIVE${RESET} - vsftpd service is not running\n"
                    
                    echo -ne "${CYAN}▹ ${RESET}Do you want to attempt to start it? (${GREEN}y${RESET}/${RED}n${RESET}): "
                    read -r start_ftp
                    if [[ "$start_ftp" == "y" || "$start_ftp" == "Y" ]]; then
                        echo -ne "${CYAN}▹ ${RESET}Starting vsftpd service... "
                        if sudo systemctl start vsftpd &>/dev/null; then
                            echo -e "${BRIGHT_GREEN}Success ✓${RESET}"
                            echo -e "\n${BRIGHT_GREEN}● ${BOLD}ACTIVE${RESET} - vsftpd service started successfully."
                        else
                            echo -e "${RED}Failed ✗${RESET}"
                            echo_error "Failed to start vsftpd. View logs with: journalctl -u vsftpd"
                        fi
                    fi
                fi
            else
                echo_warn "systemctl command not found. Cannot check vsftpd status automatically."
                echo_info "Please check manually using 'ps aux | grep vsftpd' or service status commands."
            fi
            
            echo
            echo -e "${GRAY}Note: If using a firewall, ensure ports 20, 21, and passive ports (if enabled) are open.${RESET}"
            echo
            read -r -p "Press Enter to continue..."
            show_main_menu
            ;; 
        4) 
            show_section_header "System Configuration"
            echo_info "Displaying system configuration from $CONFIG_FILE"
            echo
            
            if [ -f "$CONFIG_FILE" ]; then
                # Display configuration in a formatted way
                echo -e "${BRIGHT_WHITE}${BOLD}Configuration File:${RESET} $CONFIG_FILE"
                echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
                
                # Parse and colorize the config file
                cat "$CONFIG_FILE" | sed -E \
                    -e "s/^([^#=]+)=(.*)$/${BRIGHT_BLUE}\1${RESET}=${GREEN}\2${RESET}/" \
                    -e "s/^# (.*)$/${GRAY}# \1${RESET}/" \
                    -e "s/^#-+/${GRAY}#&${RESET}/"
                
                echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
            else
                echo_error "Configuration file $CONFIG_FILE not found."
            fi
            
            echo
            read -r -p "Press Enter to continue..."
            show_main_menu
            ;; 
        0) 
            clear
            echo -e "${BRIGHT_GREEN}Thank you for using the Secure User & Log Management System!${RESET}"
            echo -e "${GRAY}Exiting...${RESET}"
            exit 0 
            ;; 
        *) 
            echo_error "Invalid choice. Please try again."
            sleep 1
            show_main_menu
            ;; 
    esac
}

handle_user_management_menu() {
    # Functions like create_new_user are sourced from user_management.sh
    case "$1" in
        1) 
            show_section_header "Create New User"
            create_new_user
            ;; 
        2) 
            show_section_header "Delete Existing User"
            delete_existing_user
            ;; 
        3) 
            show_section_header "Modify Existing User"
            modify_existing_user
            ;; 
        4) 
            show_section_header "List Users"
            list_existing_users
            ;; 
        9) 
            show_main_menu
            return
            ;; 
        0) 
            clear
            echo -e "${BRIGHT_GREEN}Thank you for using the Secure User & Log Management System!${RESET}"
            echo -e "${GRAY}Exiting...${RESET}"
            exit 0 
            ;; 
        *) 
            echo_error "Invalid choice. Please try again."
            sleep 1
            show_user_management_menu
            return
            ;; 
    esac
    
    # After action (if not exit or back to main), pause and return to user menu
    echo
    read -r -p "Press Enter to return to User Management Menu..."
    
    # Loop back to user menu unless exited or explicitly returned to main menu
    show_user_management_menu
}

handle_log_analysis_menu() {
    case "$1" in
        1) 
            show_section_header "Generate Daily Failed Login Report"
            echo_info "Generating daily failed login report now..."
            
            if [ -x "$LOG_ANALYSIS_SCRIPT" ]; then
                # Show a spinner while running the script
                echo -ne "${CYAN}▹ ${RESET}Analyzing logs... "
                sudo "$LOG_ANALYSIS_SCRIPT" > /dev/null 2>&1 &
                local pid=$!
                spinner $pid
                wait $pid
                
                if [ $? -eq 0 ]; then
                    echo -e "${BRIGHT_GREEN}Complete ✓${RESET}"
                    echo_success "Log analysis successful. Report saved to $SECURITY_REPORT_DIR"
                else
                    echo -e "${RED}Failed ✗${RESET}"
                    echo_error "Log analysis encountered an error. Check logs for details."
                fi
            else
                echo_error "Log analysis script $LOG_ANALYSIS_SCRIPT is not executable or not found."
                echo_info "Please ensure it exists and run: sudo chmod +x $LOG_ANALYSIS_SCRIPT"
            fi
            ;;
        2) 
            show_section_header "View Latest Failed Login Report"
            echo_info "Retrieving the latest failed login report..."
            
            # Report name includes the date. Find the most recent one.
            latest_report=$(ls -1t "$SECURITY_REPORT_DIR"/failed_logins_report_*.txt 2>/dev/null | head -n 1)
            
            if [ -n "$latest_report" ] && [ -f "$latest_report" ]; then
                # Extract date from filename
                report_date=$(basename "$latest_report" | grep -oP 'failed_logins_report_\K[0-9-]+(?=\.txt)')
                
                echo -e "${BRIGHT_WHITE}${BOLD}Latest Security Report: ${RESET}${CYAN}$report_date${RESET}"
                echo -e "${GRAY}File: $latest_report${RESET}"
                echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
                echo
                
                # Display report with highlighting
                cat "$latest_report" | sed -E \
                    -e "s/^(Security Report.*)$/${BRIGHT_CYAN}${BOLD}\1${RESET}/" \
                    -e "s/^(======+)$/${CYAN}\1${RESET}/" \
                    -e "s/^(Generated on:.*)$/${GRAY}\1${RESET}/" \
                    -e "s/^(Analysis based on.*)$/${GRAY}\1${RESET}/" \
                    -e "s/^(Weekly Summary.*)$/${BRIGHT_YELLOW}${BOLD}\1${RESET}/" \
                    -e "s/^(Account Locking Check.*)$/${BRIGHT_MAGENTA}${BOLD}\1${RESET}/" \
                    -e "s/^(ALERT:.*)$/${BRIGHT_RED}${BOLD}\1${RESET}/" \
                    -e "s/^(.*Today.*)$/${YELLOW}\1${RESET}/" \
                    -e "s/(IP: [0-9.]+)/${BRIGHT_WHITE}\1${RESET}/" \
                    -e "s/(User: [^ ]+)/${BRIGHT_GREEN}\1${RESET}/"
                
                echo
                echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
                echo -e "${GRAY}End of report${RESET}"
                
            else 
                echo_warn "No reports found in $SECURITY_REPORT_DIR"
                echo_info "Expected file pattern: $SECURITY_REPORT_DIR/failed_logins_report_YYYY-MM-DD.txt"
                echo_info "You might need to generate one first (Option 1)."
            fi
            ;;
        9) 
            show_main_menu
            return
            ;; 
        0) 
            clear
            echo -e "${BRIGHT_GREEN}Thank you for using the Secure User & Log Management System!${RESET}"
            echo -e "${GRAY}Exiting...${RESET}"
            exit 0 
            ;; 
        *) 
            echo_error "Invalid choice. Please try again."
            sleep 1
            show_log_analysis_menu
            return
            ;; 
    esac
    
    echo
    read -r -p "Press Enter to return to Log Analysis Menu..."
    show_log_analysis_menu
}

# --- Main Script Execution ---
check_root >/dev/null # Just check but don't exit if not root
show_main_menu

exit 0

