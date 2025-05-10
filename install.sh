#!/bin/bash

# Secure User & Log Management System Installation Script

# --- Configuration ---
# Destination directory for the system files
DEST_DIR="/opt/secure-system"
SCRIPTS_DIR="$DEST_DIR/scripts"
CONFIG_DIR_SRC="./config" # Source config templates (logrotate)
CONFIG_DIR_DEST="$DEST_DIR/config"
LOGROTATE_CONF_DIR="/etc/logrotate.d"

# Default admin email, will be prompted if email reports are enabled
DEFAULT_ADMIN_EMAIL="admin@example.com"

# --- Helper Functions ---

echo_info() {
    echo "[INFO] $1"
}

echo_warn() {
    echo "[WARN] $1"
}

echo_error() {
    echo "[ERROR] $1" >&2
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
            echo_warn "Invalid input. Please answer 'y' or 'n'."
        fi
    done
}

# --- Pre-flight Checks ---

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo_error "This installation script must be run as root or with sudo privileges."
        exit 1
    fi
    echo_info "Running as root. Proceeding with installation."
}

check_dependencies() {
    echo_info "Checking for essential dependencies (vsftpd, openssl, cron, mailutils if emailing)..."
    local missing_pkg=0
    if ! command -v vsftpd &> /dev/null; then
        echo_warn "vsftpd is not installed. It is required for the Secure FTP Server."
        if ask_yes_no "Do you want to install vsftpd now?" "y"; then
            apt update && apt install -y vsftpd || { echo_error "Failed to install vsftpd."; exit 1; }
        else
            echo_error "vsftpd installation aborted by user. FTP setup will be skipped."
            SKIP_FTP_SETUP=true
        fi
    fi
    if ! command -v openssl &> /dev/null; then
        echo_warn "openssl is not installed. It is required for generating SSL certificates."
        if ask_yes_no "Do you want to install openssl now?" "y"; then
            apt update && apt install -y openssl || { echo_error "Failed to install openssl."; exit 1; }
        else
            echo_error "openssl installation aborted. SSL certificate generation for FTP will fail if FTP setup proceeds."
        fi
    fi
    if ! command -v crontab &> /dev/null || ! systemctl is-active --quiet cron; then 
        echo_warn "cron is not installed or not running. It is required for scheduled log analysis."
        if ask_yes_no "Do you want to install/enable cron now?" "y"; then
            apt update && apt install -y cron && systemctl enable --now cron || { echo_error "Failed to install/enable cron."; exit 1; }
        else
            echo_error "cron setup aborted by user. Scheduled tasks will not run automatically via this installer."
            SKIP_CRON_SETUP=true
        fi
    fi
    echo_info "Basic dependency check complete."
}

# --- Installation Steps ---

create_directories() {
    echo_info "Creating system directories under $DEST_DIR..."
    mkdir -p "$SCRIPTS_DIR"
    if [ $? -ne 0 ]; then echo_error "Failed to create $SCRIPTS_DIR."; exit 1; fi
    mkdir -p "$CONFIG_DIR_DEST"
    if [ $? -ne 0 ]; then echo_error "Failed to create $CONFIG_DIR_DEST."; exit 1; fi
    mkdir -p "/var/log/security_reports" 
    if [ $? -ne 0 ]; then echo_error "Failed to create /var/log/security_reports."; exit 1; fi
    chmod 750 "/var/log/security_reports"
    chown root:adm "/var/log/security_reports" 2>/dev/null || chown root:root "/var/log/security_reports" 2>/dev/null
    # Ensure user_mgmt.log directory exists if it's not /var/log/
    local user_mgmt_log_path=$(grep -oP '^USER_MGMT_LOG="\K[^"]*' "./scripts/config.sh") # Read from source config before copy
    user_mgmt_log_path=${user_mgmt_log_path:-/var/log/user_mgmt.log}
    if [ "$(dirname "$user_mgmt_log_path")" != "/var/log" ] && [ ! -d "$(dirname "$user_mgmt_log_path")" ]; then 
        mkdir -p "$(dirname "$user_mgmt_log_path")"
        chmod 750 "$(dirname "$user_mgmt_log_path")"
        chown root:adm "$(dirname "$user_mgmt_log_path")" 2>/dev/null || chown root:root "$(dirname "$user_mgmt_log_path")" 2>/dev/null
    fi
    echo_info "System directories created/ensured."
}

copy_files() {
    echo_info "Copying scripts and configuration files..."
    cp ./scripts/*.sh "$SCRIPTS_DIR/"
    if [ $? -ne 0 ]; then echo_error "Failed to copy scripts to $SCRIPTS_DIR."; exit 1; fi
    chmod +x "$SCRIPTS_DIR"/*.sh
    if [ $? -ne 0 ]; then echo_error "Failed to set execute permissions on scripts."; exit 1; fi

    cp "$CONFIG_DIR_SRC"/logrotate_* "$CONFIG_DIR_DEST/"
    if [ $? -ne 0 ]; then echo_error "Failed to copy logrotate templates to $CONFIG_DIR_DEST."; exit 1; fi

    sed "s|# SYS_BASE_DIR=.*|SYS_BASE_DIR=\"$DEST_DIR\"|" "$SCRIPTS_DIR/config.sh" > "$SCRIPTS_DIR/config.sh.tmp" && mv "$SCRIPTS_DIR/config.sh.tmp" "$SCRIPTS_DIR/config.sh"
    if [ $? -ne 0 ]; then echo_error "Failed to set SYS_BASE_DIR in config.sh."; exit 1; fi

    echo_info "Files copied and base permissions set."
}

configure_vsftpd() {
    if [ "$SKIP_FTP_SETUP" = true ]; then 
        echo_info "Skipping vsftpd configuration as per earlier choice."
        return 0
    fi

    echo_info "Configuring Secure FTP Server (vsftpd)..."
    if ! command -v vsftpd &> /dev/null; then
        echo_warn "vsftpd command not found. Skipping FTP server configuration."
        return 1
    fi
    if ! command -v openssl &> /dev/null; then
        echo_warn "openssl command not found. Cannot generate SSL certificate for vsftpd. Skipping FTP server configuration."
        return 1
    fi

    echo_info "Backing up existing vsftpd.conf to /etc/vsftpd.conf.bak_$(date +%F-%T)..."
    cp /etc/vsftpd.conf /etc/vsftpd.conf.bak_$(date +%F-%T) 2>/dev/null

    local VSFTPD_CERT_FILE_PATH=$(grep -oP 
'^VSFTPD_CERT_FILE="\K[^"]*' "$SCRIPTS_DIR/config.sh")
    local VSFTPD_KEY_FILE_PATH=$(grep -oP 
'^VSFTPD_KEY_FILE="\K[^"]*' "$SCRIPTS_DIR/config.sh")

    VSFTPD_CERT_FILE_PATH=${VSFTPD_CERT_FILE_PATH:-/etc/ssl/private/vsftpd.pem}
    VSFTPD_KEY_FILE_PATH=${VSFTPD_KEY_FILE_PATH:-/etc/ssl/private/vsftpd.pem}

    echo_info "Creating vsftpd configuration (/etc/vsftpd.conf)..."
    cat > /etc/vsftpd.conf << EOF
listen=YES
listen_ipv6=NO
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
chroot_local_user=YES
allow_writeable_chroot=YES
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd
ssl_enable=YES
allow_anon_ssl=NO
force_local_data_ssl=YES
force_local_logins_ssl=YES
ssl_tlsv1_2=YES
ssl_tlsv1_1=YES
ssl_tlsv1=YES
ssl_sslv2=NO
ssl_sslv3=NO
require_ssl_reuse=NO
ssl_ciphers=HIGH
rsa_cert_file=$VSFTPD_CERT_FILE_PATH
rsa_private_key_file=$VSFTPD_KEY_FILE_PATH
# For passive mode, uncomment and adjust if needed:
# pasv_enable=YES
# pasv_min_port=40000
# pasv_max_port=50000
EOF

    if [ ! -d "$(dirname "$VSFTPD_CERT_FILE_PATH")" ]; then
        mkdir -p "$(dirname "$VSFTPD_CERT_FILE_PATH")"
        if [ $? -ne 0 ]; then echo_error "Failed to create directory for SSL certificate: $(dirname "$VSFTPD_CERT_FILE_PATH")"; return 1; fi
    fi

    echo_info "Generating self-signed SSL certificate for vsftpd."
    echo_info "Certificate will be stored at $VSFTPD_CERT_FILE_PATH"
    echo_info "Please provide the following details for the SSL certificate:"

    local country_code state_province locality_name org_name cn_name
    read -r -p "Country Name (2 letter code) [XX]: " country_code; country_code=${country_code:-XX}
    read -r -p "State or Province Name (full name) [DefaultState]: " state_province; state_province=${state_province:-DefaultState}
    read -r -p "Locality Name (eg, city) [DefaultCity]: " locality_name; locality_name=${locality_name:-DefaultCity}
    read -r -p "Organization Name (eg, company) [DefaultCompany]: " org_name; org_name=${org_name:-DefaultCompany}
    read -r -p "Common Name (e.g. server FQDN or YOUR name) [ftp.example.com]: " cn_name; cn_name=${cn_name:-ftp.example.com}

    local subj_str="/C=$country_code/ST=$state_province/L=$locality_name/O=$org_name/CN=$cn_name"
    echo_info "Using subject: $subj_str"

    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
        -keyout "$VSFTPD_KEY_FILE_PATH" -out "$VSFTPD_CERT_FILE_PATH" \
        -subj "$subj_str"
    if [ $? -ne 0 ]; then echo_error "Failed to generate SSL certificate."; return 1; fi
    chmod 600 "$VSFTPD_KEY_FILE_PATH" "$VSFTPD_CERT_FILE_PATH"

    if [ ! -d /var/run/vsftpd/empty ]; then mkdir -p /var/run/vsftpd/empty; fi
    if [ $? -ne 0 ]; then echo_error "Failed to create /var/run/vsftpd/empty."; return 1; fi

    echo_info "Restarting and enabling vsftpd service..."
    systemctl restart vsftpd
    if [ $? -ne 0 ]; then echo_error "Failed to restart vsftpd. Check 'journalctl -u vsftpd' or '/var/log/vsftpd.log'."; return 1; fi
    systemctl enable vsftpd
    if [ $? -ne 0 ]; then echo_warn "Failed to enable vsftpd to start on boot."; fi

    echo_info "vsftpd configuration complete. If using a firewall, ensure ports 20, 21, and passive ports are open."
}

configure_logrotate() {
    echo_info "Configuring log rotation..."
    local user_mgmt_freq=$(grep -oP '^LOGROTATE_USER_MGMT_FREQUENCY="\K[^"]*' "$SCRIPTS_DIR/config.sh")
    local user_mgmt_keep=$(grep -oP '^LOGROTATE_USER_MGMT_KEEP="\K[^"]*' "$SCRIPTS_DIR/config.sh")
    local reports_freq=$(grep -oP '^LOGROTATE_SECURITY_REPORTS_FREQUENCY="\K[^"]*' "$SCRIPTS_DIR/config.sh")
    local reports_keep=$(grep -oP '^LOGROTATE_SECURITY_REPORTS_KEEP="\K[^"]*' "$SCRIPTS_DIR/config.sh")

    user_mgmt_freq=${user_mgmt_freq:-weekly}; user_mgmt_keep=${user_mgmt_keep:-4}
    reports_freq=${reports_freq:-daily}; reports_keep=${reports_keep:-30}

    local logrotate_user_mgmt_tpl="$CONFIG_DIR_DEST/logrotate_user_mgmt"
    local logrotate_user_mgmt_final="$LOGROTATE_CONF_DIR/secure_system_user_mgmt"
    cp "$logrotate_user_mgmt_tpl" "$logrotate_user_mgmt_final"
    sed -i "s/^    weekly/    $user_mgmt_freq/" "$logrotate_user_mgmt_final"
    sed -i "s/^    rotate 4/    rotate $user_mgmt_keep/" "$logrotate_user_mgmt_final"
    # Update log path in template if necessary, though it should be generic
    local user_mgmt_log_path_for_rotate=$(grep -oP '^USER_MGMT_LOG="\K[^"]*' "$SCRIPTS_DIR/config.sh")
    user_mgmt_log_path_for_rotate=${user_mgmt_log_path_for_rotate:-/var/log/user_mgmt.log}
    sed -i "s|^/var/log/user_mgmt.log|$user_mgmt_log_path_for_rotate|" "$logrotate_user_mgmt_final"

    local logrotate_reports_tpl="$CONFIG_DIR_DEST/logrotate_security_reports"
    local logrotate_reports_final="$LOGROTATE_CONF_DIR/secure_system_security_reports"
    cp "$logrotate_reports_tpl" "$logrotate_reports_final"
    sed -i "s/^    daily/    $reports_freq/" "$logrotate_reports_final"
    sed -i "s/^    rotate 30/    rotate $reports_keep/" "$logrotate_reports_final"
    local security_reports_dir_for_rotate=$(grep -oP '^SECURITY_REPORT_DIR="\K[^"]*' "$SCRIPTS_DIR/config.sh")
    security_reports_dir_for_rotate=${security_reports_dir_for_rotate:-/var/log/security_reports}
    sed -i "s|^/var/log/security_reports/\*.txt|$security_reports_dir_for_rotate/*.txt|" "$logrotate_reports_final"

    echo_info "Logrotate configurations placed in $LOGROTATE_CONF_DIR."
}

configure_cron_jobs() {
    if [ "$SKIP_CRON_SETUP" = true ]; then
        echo_info "Skipping cron job setup as per earlier choice."
        echo_warn "Manual cron setup required for daily log analysis: 0 0 * * * $SCRIPTS_DIR/log_analysis.sh"
        return 0
    fi
    echo_info "Configuring cron job for daily log analysis..."
    local log_analysis_cmd="$SCRIPTS_DIR/log_analysis.sh"
    
    (crontab -l 2>/dev/null | grep -v -F "$log_analysis_cmd" ; echo "0 0 * * * $log_analysis_cmd") | crontab -
    if [ $? -eq 0 ]; then
        echo_info "Cron job for daily log analysis scheduled."
        echo_info "Note: In some environments, cron daemon might need a restart or this script might not have permission to modify other users' crontabs."
        echo_info "Please verify with 'sudo crontab -l' if running as root, or 'crontab -l' for the current user."
    else
        echo_error "Failed to schedule cron job for log analysis. Add manually: 0 0 * * * $log_analysis_cmd"
    fi
}

configure_bonus_features_interactive() {
    echo_info "--- Configuring Bonus Features (Interactive) ---"
    local config_script_path="$SCRIPTS_DIR/config.sh"
    local admin_email_val=""

    if ask_yes_no "Enable daily security reports via email?" "n"; then
        sed -i 's/^SEND_EMAIL_REPORTS=.*/SEND_EMAIL_REPORTS="true"/' "$config_script_path"
        echo_info "Email reporting enabled in $config_script_path."
        
        if ! command -v mail &> /dev/null && ! command -v mailx &> /dev/null; then
            echo_warn "'mailutils' (provides 'mail' command) is not installed. Required for sending emails."
            if ask_yes_no "Install mailutils now?" "y"; then
                apt update && apt install -y mailutils || echo_error "Failed to install mailutils. Email reporting might fail."
            else
                echo_warn "mailutils not installed by choice. Email reporting might fail."
            fi
        fi
        
        while true; do
            read -r -p "Enter administrator email for reports [$DEFAULT_ADMIN_EMAIL]: " admin_email_val
            admin_email_val=${admin_email_val:-$DEFAULT_ADMIN_EMAIL}
            if [[ "$admin_email_val" == "" || "$admin_email_val" != *@* ]]; then # Basic check for @
                echo_warn "Invalid email format. Please enter a valid email address."
            else
                # Escape for sed
                local escaped_admin_email_val=$(printf '%s
' "$admin_email_val" | sed 's:[\/&]:\\&:g')
                sed -i "s|^ADMIN_EMAIL=.*|ADMIN_EMAIL=\"$escaped_admin_email_val\"|" "$config_script_path"
                echo_info "Administrator email set to $admin_email_val."
                break
            fi
        done
    else
        sed -i 's/^SEND_EMAIL_REPORTS=.*/SEND_EMAIL_REPORTS="false"/' "$config_script_path"
        sed -i 's/^ADMIN_EMAIL=.*/ADMIN_EMAIL=""/' "$config_script_path"
        echo_info "Email reporting disabled."
    fi

    if ask_yes_no "Include weekly summary of failed logins in daily reports?" "n"; then
        sed -i 's/^INCLUDE_WEEKLY_SUMMARY=.*/INCLUDE_WEEKLY_SUMMARY="true"/' "$config_script_path"
        echo_info "Weekly summary enabled."
    else
        sed -i 's/^INCLUDE_WEEKLY_SUMMARY=.*/INCLUDE_WEEKLY_SUMMARY="false"/' "$config_script_path"
        echo_info "Weekly summary disabled."
    fi

    if ask_yes_no "Enable automatic account locking check (conceptual feature in reports)?" "n"; then
        sed -i 's/^ENABLE_ACCOUNT_LOCKING=.*/ENABLE_ACCOUNT_LOCKING="true"/' "$config_script_path"
        local max_fails_val
        read -r -p "Enter max failed attempts before account is flagged (default 5): " max_fails_val
        max_fails_val=${max_fails_val:-5}
        if ! [[ "$max_fails_val" =~ ^[0-9]+$ ]]; then max_fails_val=5; echo_warn "Invalid input, using default 5."; fi
        sed -i "s/^MAX_FAILED_ATTEMPTS=.*/MAX_FAILED_ATTEMPTS=$max_fails_val/" "$config_script_path"
        echo_info "Account locking check (conceptual) enabled. Max attempts: $max_fails_val."
        echo_warn "Note: Account locking check in log_analysis.sh is illustrative. For production, use pam_tally2 or fail2ban."
    else
        sed -i 's/^ENABLE_ACCOUNT_LOCKING=.*/ENABLE_ACCOUNT_LOCKING="false"/' "$config_script_path"
        echo_info "Account locking check (conceptual) disabled."
    fi
}

# --- Main Installation Logic ---

main() {
    echo_info "Starting Secure User & Log Management System installation..."
    
    check_root
    check_dependencies
    
    create_directories
    copy_files
    
    configure_vsftpd
    configure_logrotate
    configure_cron_jobs
    
    # Configure bonus features interactively
    configure_bonus_features_interactive

    echo_info "-----------------------------------------------------------------"
    echo_info " Secure User & Log Management System Installation Complete! "
    echo_info "-----------------------------------------------------------------"
    echo_info "The main interface script: $SCRIPTS_DIR/secure_system.sh"
    echo_info "Run with: sudo $SCRIPTS_DIR/secure_system.sh"
    echo_info "Configuration: $SCRIPTS_DIR/config.sh (Review for bonus feature settings)"
    echo_info "User management logs: $(grep -oP '^USER_MGMT_LOG="\K[^"]*' "$SCRIPTS_DIR/config.sh")"
    echo_info "Security reports: $(grep -oP '^SECURITY_REPORT_DIR="\K[^"]*' "$SCRIPTS_DIR/config.sh")"
    echo_info "Cron job for log analysis should be active. Verify with 'sudo crontab -l'."
    echo_info "If FTP is used, ensure firewall rules are set for ports 20, 21 and passive range."
    echo_info "Installation log (this output) is not saved. Please copy if needed."
}

main

exit 0

