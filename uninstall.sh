#!/bin/bash

# Secure User & Log Management System Uninstallation Script

# --- Configuration (should match install.sh defaults or be read from config if possible) ---
DEST_DIR="/opt/secure-system"
SCRIPTS_DIR="$DEST_DIR/scripts"
LOGROTATE_CONF_DIR="/etc/logrotate.d"
SYMLINK_PATH="/usr/local/bin/seclogs"
USER_MGMT_LOG_DEFAULT="/var/log/user_mgmt.log"
SECURITY_REPORT_DIR_DEFAULT="/var/log/security_reports"
LOGROTATE_USER_MGMT_CONF="$LOGROTATE_CONF_DIR/secure_system_user_mgmt"
LOGROTATE_REPORTS_CONF="$LOGROTATE_CONF_DIR/secure_system_security_reports"

# --- Color Definitions ---
RED="\e[0;31m"
GREEN="\e[0;32m"
YELLOW="\e[0;33m"
BLUE="\e[0;34m"
MAGENTA="\e[0;35m"
CYAN="\e[0;36m"
WHITE="\e[0;37m"
BOLD="\e[1m"
NC="\e[0m" # No Color

# --- Helper Functions ---
echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

ask_yes_no() {
    local question="$1"
    local default_answer="$2" # "y" or "n"
    local answer

    while true; do
        if [ "$default_answer" == "y" ]; then
            read -r -p "$question (Y/n): " answer
            answer=${answer:-Y}
        elif [ "$default_answer" == "n" ]; then
            read -r -p "$question (y/N): " answer
            answer=${answer:-N}
        else
            read -r -p "$question (y/n): " answer
        fi

        if [[ "$answer" =~ ^[Yy]$ ]]; then
            return 0 # Yes
        elif [[ "$answer" =~ ^[Nn]$ ]]; then
            return 1 # No
        else
            echo_warn "Invalid input. Please answer \'y\' or \'n\'."
        fi
    done
}

# --- Pre-flight Checks ---
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo_error "This uninstallation script must be run as root or with sudo privileges."
        exit 1
    fi
    echo_info "Running as root. Proceeding with uninstallation."
}

# --- Uninstallation Steps ---

remove_symlink() {
    echo_info "Removing symlink $SYMLINK_PATH..."
    if [ -L "$SYMLINK_PATH" ]; then
        rm -f "$SYMLINK_PATH"
        if [ $? -eq 0 ]; then
            echo_info "Symlink $SYMLINK_PATH removed successfully."
        else
            echo_error "Failed to remove symlink $SYMLINK_PATH. Please remove it manually."
        fi
    else
        echo_warn "Symlink $SYMLINK_PATH not found or is not a symlink. Skipping."
    fi
}

remove_cron_job() {
    echo_info "Removing cron job for log analysis..."
    local log_analysis_script_path="$SCRIPTS_DIR/log_analysis.sh"
    if crontab -l 2>/dev/null | grep -q -F "$log_analysis_script_path"; then
        (crontab -l 2>/dev/null | grep -v -F "$log_analysis_script_path") | crontab -
        if [ $? -eq 0 ]; then
            echo_info "Cron job for $log_analysis_script_path removed."
        else
            echo_error "Failed to remove cron job automatically. Please remove it manually using \'sudo crontab -e\'."
        fi
    else
        echo_warn "Cron job for $log_analysis_script_path not found. Skipping."
    fi
}

remove_logrotate_configs() {
    echo_info "Removing logrotate configurations..."
    if [ -f "$LOGROTATE_USER_MGMT_CONF" ]; then
        rm -f "$LOGROTATE_USER_MGMT_CONF"
        echo_info "Removed $LOGROTATE_USER_MGMT_CONF."
    else
        echo_warn "Logrotate config $LOGROTATE_USER_MGMT_CONF not found. Skipping."
    fi
    if [ -f "$LOGROTATE_REPORTS_CONF" ]; then
        rm -f "$LOGROTATE_REPORTS_CONF"
        echo_info "Removed $LOGROTATE_REPORTS_CONF."
    else
        echo_warn "Logrotate config $LOGROTATE_REPORTS_CONF not found. Skipping."
    fi
}

remove_system_files() {
    echo_info "Removing system files from $DEST_DIR..."
    if [ -d "$DEST_DIR" ]; then
        rm -rf "$DEST_DIR"
        if [ $? -eq 0 ]; then
            echo_info "System files directory $DEST_DIR removed successfully."
        else
            echo_error "Failed to remove $DEST_DIR. Please remove it manually."
        fi
    else
        echo_warn "System files directory $DEST_DIR not found. Skipping."
    fi
}

remove_logs_and_reports() {
    local user_mgmt_log_path=$USER_MGMT_LOG_DEFAULT
    local security_report_dir=$SECURITY_REPORT_DIR_DEFAULT

    if ask_yes_no "Do you want to remove user management logs ($user_mgmt_log_path)?" "n"; then
        if [ -f "$user_mgmt_log_path" ]; then
            rm -f "$user_mgmt_log_path"
            echo_info "Removed $user_mgmt_log_path."
        else
            echo_warn "Log file $user_mgmt_log_path not found."
        fi
    fi

    if ask_yes_no "Do you want to remove security reports directory ($security_report_dir)?" "n"; then
        if [ -d "$security_report_dir" ]; then
            rm -rf "$security_report_dir"
            echo_info "Removed $security_report_dir."
        else
            echo_warn "Security reports directory $security_report_dir not found."
        fi
    fi
}

vsftpd_cleanup_info() {
    echo_info "--- VSFTPD Cleanup Information ---"
    echo_warn "This script does not automatically uninstall vsftpd or revert its configuration."
    echo_info "If you wish to revert vsftpd configuration, the installer may have created a backup (e.g., /etc/vsftpd.conf.bak_YYYY-MM-DD-HH:MM:SS)."
    echo_info "To remove vsftpd entirely (if it was installed for this tool): sudo apt purge vsftpd"
    echo_info "The SSL certificate used by vsftpd (e.g., /etc/ssl/private/vsftpd.pem) can also be manually removed if no longer needed."
}

# --- Main Uninstallation Logic ---
main() {
    echo_info "Starting Secure User & Log Management System uninstallation..."
    
    check_root

    if ! ask_yes_no "Are you sure you want to uninstall the Secure User & Log Management System? This will remove its files and configurations." "n"; then
        echo_info "Uninstallation aborted by user."
        exit 0
    fi

    remove_symlink
    remove_cron_job
    remove_logrotate_configs
    remove_system_files 
    remove_logs_and_reports 
    vsftpd_cleanup_info

    echo -e "\n${BLUE}${BOLD}-----------------------------------------------------------------${NC}"
    echo -e " ${MAGENTA}${BOLD}Secure User & Log Management System Uninstallation Complete!${NC} "
    echo -e "${BLUE}${BOLD}-----------------------------------------------------------------${NC}"
    echo_info "Please review any manual steps mentioned above if applicable."
    echo_info "Consider rebooting or restarting services if you suspect any residual processes (though unlikely for this script-based tool)."
}

main

exit 0

