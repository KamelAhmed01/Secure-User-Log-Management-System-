#!/bin/bash

# Secure System Main Interface Script (Core Functionality)
# Provides a menu-driven interface to access various system functions.

# Get the directory where the script is located
SCRIPT_DIR="$(dirname "$0")"

# Source configuration and other scripts
CONFIG_FILE="$SCRIPT_DIR/config.sh"
USER_MGMT_SCRIPT="$SCRIPT_DIR/user_management.sh"
LOG_ANALYSIS_SCRIPT="$SCRIPT_DIR/log_analysis.sh"

# Check if running as root, as many operations require it
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "This script needs to be run as root or with sudo privileges for most operations." >&2
        # For core operations, especially user management and vsftpd control, root is essential.
        # Allow to proceed but functions will likely fail if not root.
        # The user_management.sh script uses sudo internally for its commands.
    fi
}

# Load configuration
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "Critical Error: Configuration file $CONFIG_FILE not found." >&2
    echo "Please ensure the system is installed correctly or run the install.sh script." >&2
    exit 1
fi

# Check for dependent scripts
if [ ! -f "$USER_MGMT_SCRIPT" ]; then
    echo "Critical Error: User management script $USER_MGMT_SCRIPT not found." >&2
    exit 1
fi
if [ ! -f "$LOG_ANALYSIS_SCRIPT" ]; then
    echo "Critical Error: Log analysis script $LOG_ANALYSIS_SCRIPT not found." >&2
    exit 1
fi

# Source the user management script to make its functions available in this script's scope
source "$USER_MGMT_SCRIPT"

# --- Display Menus ---

show_main_menu() {
    clear
    echo "======================================="
    echo " Secure User & Log Management System "
    echo "======================================="
    echo " (Core Functionality)"
    echo "---------------------------------------"
    echo "1. User Management"
    echo "2. Log Analysis & Reporting"
    echo "3. Secure FTP Server Status"
    echo "4. View System Configuration"
    echo "0. Exit"
    echo "---------------------------------------"
    read -r -p "Enter your choice [0-4]: " main_choice
    handle_main_menu "$main_choice"
}

show_user_management_menu() {
    clear
    echo "---------------------------------------"
    echo " User Management Menu "
    echo "---------------------------------------"
    echo "1. Create New User"
    echo "2. Delete Existing User"
    echo "3. Modify Existing User"
    echo "4. List Users"
    echo "9. Back to Main Menu"
    echo "0. Exit"
    echo "---------------------------------------"
    read -r -p "Enter your choice [0-4, 9]: " um_choice
    handle_user_management_menu "$um_choice"
}

show_log_analysis_menu() {
    clear
    echo "---------------------------------------"
    echo " Log Analysis & Reporting Menu "
    echo "---------------------------------------"
    echo "1. Generate Daily Failed Login Report (Now)"
    echo "2. View Latest Failed Login Report"
    echo "9. Back to Main Menu"
    echo "0. Exit"
    echo "---------------------------------------"
    read -r -p "Enter your choice [0-2, 9]: " la_choice
    handle_log_analysis_menu "$la_choice"
}

# --- Handle Menu Choices ---

handle_main_menu() {
    case "$1" in
        1) show_user_management_menu ;; 
        2) show_log_analysis_menu ;; 
        3) 
            echo "Checking Secure FTP Server (vsftpd) status..."
            if command -v systemctl &> /dev/null; then
                if systemctl is-active --quiet vsftpd; then
                    echo "vsftpd service is active (running)."
                    sudo systemctl status vsftpd --no-pager
                else
                    echo "vsftpd service is not active."
                    read -r -p "Do you want to attempt to start it? (y/n): " start_ftp
                    if [[ "$start_ftp" == "y" || "$start_ftp" == "Y" ]]; then
                        sudo systemctl start vsftpd
                        if systemctl is-active --quiet vsftpd; then
                            echo "vsftpd service started successfully."
                        else
                            echo "Failed to start vsftpd. Check logs: sudo journalctl -u vsftpd or /var/log/vsftpd.log"
                        fi
                    fi
                fi
            else
                echo "systemctl command not found. Cannot check vsftpd status automatically."
                echo "Please check manually, e.g., using 'ps aux | grep vsftpd' or service status commands."
            fi
            read -r -p "Press Enter to continue..."
            show_main_menu
            ;; 
        4) 
            clear
            echo "--- System Configuration Overview (from $CONFIG_FILE) ---"
            if [ -f "$CONFIG_FILE" ]; then
                cat "$CONFIG_FILE"
            else
                echo "Error: Configuration file $CONFIG_FILE not found."
            fi
            echo "--- End of Configuration ---"
            read -r -p "Press Enter to continue..."
            show_main_menu
            ;; 
        0) echo "Exiting Secure System Management. Goodbye!"; exit 0 ;; 
        *) echo "Invalid choice. Please try again."; sleep 1; show_main_menu ;; 
    esac
}

handle_user_management_menu() {
    # Functions like create_new_user are sourced from user_management.sh
    case "$1" in
        1) create_new_user ;; 
        2) delete_existing_user ;; 
        3) modify_existing_user ;; 
        4) list_existing_users ;; 
        9) show_main_menu ;; 
        0) echo "Exiting Secure System Management. Goodbye!"; exit 0 ;; 
        *) echo "Invalid choice. Please try again."; sleep 1; show_user_management_menu ;; 
    esac
    # After action (if not exit or back to main), pause and return to user menu
    if [[ "$1" -ge 1 && "$1" -le 4 ]]; then
        read -r -p "Press Enter to return to User Management Menu..."
    fi
    # Loop back to user menu unless exited or explicitly returned to main menu
    if [[ "$1" != "9" && "$1" != "0" ]]; then
      show_user_management_menu
    fi
}

handle_log_analysis_menu() {
    case "$1" in
        1) 
            echo "Generating daily failed login report now..."
            if [ -x "$LOG_ANALYSIS_SCRIPT" ]; then
                # Execute the script. It handles its own output and logging.
                # It should be run with sudo if it needs to read restricted logs or write to restricted dirs
                sudo "$LOG_ANALYSIS_SCRIPT"
                echo "Log analysis script execution finished. Report should be in $SECURITY_REPORT_DIR"
            else
                echo "Error: Log analysis script $LOG_ANALYSIS_SCRIPT is not executable or not found." >&2
                echo "Please ensure it exists and run: sudo chmod +x $LOG_ANALYSIS_SCRIPT"
            fi
            ;;
        2) 
            echo "Displaying the latest failed login report..."
            # Report name includes the date. Find the most recent one.
            # Example: failed_logins_report_YYYY-MM-DD.txt
            latest_report=$(ls -1t "$SECURITY_REPORT_DIR"/failed_logins_report_*.txt 2>/dev/null | head -n 1)
            if [ -n "$latest_report" ] && [ -f "$latest_report" ]; then
                echo "Latest report: $latest_report"
                echo "--- Report Content ---"
                cat "$latest_report"
                echo "--- End of Report ---"
            else 
                echo "No reports found in $SECURITY_REPORT_DIR (expected: $SECURITY_REPORT_DIR/failed_logins_report_YYYY-MM-DD.txt)."
                echo "You might need to generate one first (Option 1)."
            fi
            ;;
        9) show_main_menu ;; 
        0) echo "Exiting Secure System Management. Goodbye!"; exit 0 ;; 
        *) echo "Invalid choice. Please try again."; sleep 1; show_log_analysis_menu ;; 
    esac
    if [[ "$1" -ge 1 && "$1" -le 2 ]]; then
        read -r -p "Press Enter to return to Log Analysis Menu..."
    fi
    if [[ "$1" != "9" && "$1" != "0" ]]; then
      show_log_analysis_menu
    fi
}

# --- Main Script Execution ---
check_root
show_main_menu

exit 0

