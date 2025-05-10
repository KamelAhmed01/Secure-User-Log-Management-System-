#!/bin/bash

# Secure User & Log Management System Installation Script

# --- Terminal Colors and Styling ---
# These definitions are needed here since this script creates colors.sh
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

# --- Configuration ---
# Destination directory for the system files
DEST_DIR="/opt/secure-system"
SCRIPTS_DIR="$DEST_DIR/scripts"
CONFIG_DIR_SRC="./config" # Source config templates (logrotate)
CONFIG_DIR_DEST="$DEST_DIR/config"
LOGROTATE_CONF_DIR="/etc/logrotate.d"

# Default admin email, will be prompted if email reports are enabled
DEFAULT_ADMIN_EMAIL="admin@example.com"

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
    echo -e "${DIM}                           Installation Wizard${RESET}"
    echo
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo
}

# Show header for each section
show_section_header() {
    echo
    echo -e "${YELLOW}${BOLD}[ ${1} ]${RESET}"
    divider
}

# Show progress spinner
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

# Progress bar for longer operations
progress_bar() {
    local duration=$1
    local progress=0
    local total=20
    local step=$((duration / total))
    
    echo -ne "${GRAY}[${RESET}"
    for ((i=0; i<total; i++)); do
        echo -ne "${GRAY}░${RESET}"
    done
    echo -ne "${GRAY}]${RESET} 0%"
    
    for ((i=0; i<total; i++)); do
        sleep $step
        progress=$((i+1))
        percent=$((progress * 100 / total))
        echo -ne "\r${GRAY}[${RESET}"
        
        for ((j=0; j<progress; j++)); do
            echo -ne "${GREEN}█${RESET}"
        done
        
        for ((j=progress; j<total; j++)); do
            echo -ne "${GRAY}░${RESET}"
        done
        
        echo -ne "${GRAY}]${RESET} ${percent}%"
    done
    echo
}

# --- Helper Functions ---
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

ask_yes_no() {
    local question="$1"
    local default_answer="$2" # "y" or "n"
    local prompt
    local answer

    if [ "$default_answer" == "y" ]; then
        prompt="${BOLD}${question}${RESET} (${BRIGHT_GREEN}Y${RESET}/${RED}n${RESET}): "
    elif [ "$default_answer" == "n" ]; then
        prompt="${BOLD}${question}${RESET} (${GREEN}y${RESET}/${BRIGHT_RED}N${RESET}): "
    else
        prompt="${BOLD}${question}${RESET} (${GREEN}y${RESET}/${RED}n${RESET}): "
    fi

    while true; do
        echo -ne "$prompt"
        read -r answer
        
        if [ "$default_answer" == "y" ]; then
            answer=${answer:-Y}
        elif [ "$default_answer" == "n" ]; then
            answer=${answer:-N}
        fi

        if [[ "$answer" =~ ^[Yy]$ ]]; then
            return 0 # Yes
        elif [[ "$answer" =~ ^[Nn]$ ]]; then
            return 1 # No
        else
            echo -e "${YELLOW}⚠ Invalid input. Please answer '${GREEN}y${YELLOW}' or '${RED}n${YELLOW}'.${RESET}"
        fi
    done
}

# --- Pre-flight Checks ---
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo_error "This installation script must be run as root or with sudo privileges."
        echo -e "${BRIGHT_YELLOW}Tip:${RESET} Try running the script with 'sudo $0'"
        exit 1
    fi
    echo_success "Running as root. Proceeding with installation."
}

check_dependencies() {
    show_section_header "Checking Dependencies"
    echo_info "Checking for essential dependencies..."
    
    local missing_pkg=0
    
    # Check for vsftpd
    echo -ne "${CYAN}▹ ${RESET}Checking for ${BOLD}vsftpd${RESET}... "
    if command -v vsftpd &> /dev/null; then
        echo -e "${BRIGHT_GREEN}Found ✓${RESET}"
    else
        echo -e "${YELLOW}Not found ✗${RESET}"
        echo_warn "vsftpd is not installed. It is required for the Secure FTP Server."
        
        if ask_yes_no "Do you want to install vsftpd now?" "y"; then
            echo -ne "${CYAN}▹ ${RESET}Installing ${BOLD}vsftpd${RESET}... "
            apt update > /dev/null 2>&1 && apt install -y vsftpd > /dev/null 2>&1
            
            if [ $? -eq 0 ]; then
                echo -e "${BRIGHT_GREEN}Success ✓${RESET}"
            else
                echo -e "${RED}Failed ✗${RESET}"
                echo_error "Failed to install vsftpd."
                exit 1
            fi
        else
            echo_warn "vsftpd installation aborted by user. FTP setup will be skipped."
            SKIP_FTP_SETUP=true
        fi
    fi
    
    # Check for openssl
    echo -ne "${CYAN}▹ ${RESET}Checking for ${BOLD}openssl${RESET}... "
    if command -v openssl &> /dev/null; then
        echo -e "${BRIGHT_GREEN}Found ✓${RESET}"
    else
        echo -e "${YELLOW}Not found ✗${RESET}"
        echo_warn "openssl is not installed. It is required for generating SSL certificates."
        
        if ask_yes_no "Do you want to install openssl now?" "y"; then
            echo -ne "${CYAN}▹ ${RESET}Installing ${BOLD}openssl${RESET}... "
            apt update > /dev/null 2>&1 && apt install -y openssl > /dev/null 2>&1
            
            if [ $? -eq 0 ]; then
                echo -e "${BRIGHT_GREEN}Success ✓${RESET}"
            else
                echo -e "${RED}Failed ✗${RESET}"
                echo_error "Failed to install openssl."
                exit 1
            fi
        else
            echo_warn "openssl installation aborted. SSL certificate generation for FTP will fail if FTP setup proceeds."
        fi
    fi
    
    # Check for cron
    echo -ne "${CYAN}▹ ${RESET}Checking for ${BOLD}cron${RESET}... "
    if command -v crontab &> /dev/null && systemctl is-active --quiet cron; then
        echo -e "${BRIGHT_GREEN}Found and active ✓${RESET}"
    else
        echo -e "${YELLOW}Not found or not active ✗${RESET}"
        echo_warn "cron is not installed or not running. It is required for scheduled log analysis."
        
        if ask_yes_no "Do you want to install/enable cron now?" "y"; then
            echo -ne "${CYAN}▹ ${RESET}Installing/enabling ${BOLD}cron${RESET}... "
            apt update > /dev/null 2>&1 && apt install -y cron > /dev/null 2>&1 && systemctl enable --now cron > /dev/null 2>&1
            
            if [ $? -eq 0 ]; then
                echo -e "${BRIGHT_GREEN}Success ✓${RESET}"
            else
                echo -e "${RED}Failed ✗${RESET}"
                echo_error "Failed to install/enable cron."
                exit 1
            fi
        else
            echo_warn "cron setup aborted by user. Scheduled tasks will not run automatically via this installer."
            SKIP_CRON_SETUP=true
        fi
    fi
    
    echo_success "Dependency check complete."
}

# --- Installation Steps ---
create_directories() {
    show_section_header "Creating System Directories"
    echo_info "Creating system directories under ${BOLD}$DEST_DIR${RESET}..."
    
    echo -ne "${CYAN}▹ ${RESET}Creating scripts directory... "
    mkdir -p "$SCRIPTS_DIR"
    if [ $? -ne 0 ]; then 
        echo -e "${RED}Failed ✗${RESET}"
        echo_error "Failed to create $SCRIPTS_DIR."
        exit 1
    fi
    echo -e "${BRIGHT_GREEN}Done ✓${RESET}"
    
    echo -ne "${CYAN}▹ ${RESET}Creating config directory... "
    mkdir -p "$CONFIG_DIR_DEST"
    if [ $? -ne 0 ]; then 
        echo -e "${RED}Failed ✗${RESET}"
        echo_error "Failed to create $CONFIG_DIR_DEST."
        exit 1
    fi
    echo -e "${BRIGHT_GREEN}Done ✓${RESET}"
    
    echo -ne "${CYAN}▹ ${RESET}Creating security reports directory... "
    mkdir -p "/var/log/security_reports" 
    if [ $? -ne 0 ]; then 
        echo -e "${RED}Failed ✗${RESET}"
        echo_error "Failed to create /var/log/security_reports."
        exit 1
    fi
    echo -e "${BRIGHT_GREEN}Done ✓${RESET}"
    
    echo -ne "${CYAN}▹ ${RESET}Setting permissions... "
    chmod 750 "/var/log/security_reports"
    chown root:adm "/var/log/security_reports" 2>/dev/null || chown root:root "/var/log/security_reports" 2>/dev/null
    echo -e "${BRIGHT_GREEN}Done ✓${RESET}"
    
    # Ensure user_mgmt.log directory exists if it's not /var/log/
    local user_mgmt_log_path=$(grep -oP '^USER_MGMT_LOG="\K[^"]*' "./scripts/config.sh" 2>/dev/null)
    user_mgmt_log_path=${user_mgmt_log_path:-/var/log/user_mgmt.log}
    
    if [ "$(dirname "$user_mgmt_log_path")" != "/var/log" ] && [ ! -d "$(dirname "$user_mgmt_log_path")" ]; then 
        echo -ne "${CYAN}▹ ${RESET}Creating user management log directory... "
        mkdir -p "$(dirname "$user_mgmt_log_path")"
        chmod 750 "$(dirname "$user_mgmt_log_path")"
        chown root:adm "$(dirname "$user_mgmt_log_path")" 2>/dev/null || chown root:root "$(dirname "$user_mgmt_log_path")" 2>/dev/null
        echo -e "${BRIGHT_GREEN}Done ✓${RESET}"
    fi
    
    echo_success "System directories created successfully."
}

copy_files() {
    show_section_header "Copying Files"
    echo_info "Copying scripts and configuration files..."
    
    echo -ne "${CYAN}▹ ${RESET}Copying shell scripts... "
    cp ./scripts/*.sh "$SCRIPTS_DIR/" 2>/dev/null
    if [ $? -ne 0 ]; then 
        echo -e "${RED}Failed ✗${RESET}"
        echo_error "Failed to copy scripts to $SCRIPTS_DIR."
        exit 1
    fi
    echo -e "${BRIGHT_GREEN}Done ✓${RESET}"
    
    echo -ne "${CYAN}▹ ${RESET}Setting execute permissions... "
    chmod +x "$SCRIPTS_DIR"/*.sh
    if [ $? -ne 0 ]; then 
        echo -e "${RED}Failed ✗${RESET}"
        echo_error "Failed to set execute permissions on scripts."
        exit 1
    fi
    echo -e "${BRIGHT_GREEN}Done ✓${RESET}"
    
    echo -ne "${CYAN}▹ ${RESET}Copying logrotate templates... "
    cp "$CONFIG_DIR_SRC"/logrotate_* "$CONFIG_DIR_DEST/" 2>/dev/null
    if [ $? -ne 0 ]; then 
        echo -e "${RED}Failed ✗${RESET}"
        echo_error "Failed to copy logrotate templates to $CONFIG_DIR_DEST."
        exit 1
    fi
    echo -e "${BRIGHT_GREEN}Done ✓${RESET}"
    
    echo -ne "${CYAN}▹ ${RESET}Updating base directory in config... "
    sed "s|# SYS_BASE_DIR=.*|SYS_BASE_DIR=\"$DEST_DIR\"|" "$SCRIPTS_DIR/config.sh" > "$SCRIPTS_DIR/config.sh.tmp" && mv "$SCRIPTS_DIR/config.sh.tmp" "$SCRIPTS_DIR/config.sh"
    if [ $? -ne 0 ]; then 
        echo -e "${RED}Failed ✗${RESET}"
        echo_error "Failed to set SYS_BASE_DIR in config.sh."
        exit 1
    fi
    echo -e "${BRIGHT_GREEN}Done ✓${RESET}"
    
    echo -ne "${CYAN}▹ ${RESET}Creating colors and styling file... "
    cat > "$SCRIPTS_DIR/colors.sh" << 'EOL'
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

# Section header - updated to use divider function
show_section_header() {
    echo
    echo -e "${YELLOW}${BOLD}[ ${1} ]${RESET}"
    divider
}
EOL
chmod +x "$SCRIPTS_DIR/colors.sh"
echo -e "${BRIGHT_GREEN}Done ✓${RESET}"
    
    echo_success "Files copied and configured successfully."
}

configure_vsftpd() {
    show_section_header "Configuring Secure FTP Server"
    
    if [ "$SKIP_FTP_SETUP" = true ]; then 
        echo_info "Skipping vsftpd configuration as per earlier choice."
        return 0
    fi

    echo_info "Setting up the Secure FTP Server (vsftpd)..."
    
    if ! command -v vsftpd &> /dev/null; then
        echo_warn "vsftpd command not found. Skipping FTP server configuration."
        return 1
    fi
    
    if ! command -v openssl &> /dev/null; then
        echo_warn "openssl command not found. Cannot generate SSL certificate for vsftpd. Skipping FTP server configuration."
        return 1
    fi

    echo -ne "${CYAN}▹ ${RESET}Backing up existing configuration... "
    cp /etc/vsftpd.conf /etc/vsftpd.conf.bak_$(date +%F-%T) 2>/dev/null
    echo -e "${BRIGHT_GREEN}Done ✓${RESET}"

    local VSFTPD_CERT_FILE_PATH=$(grep -oP '^VSFTPD_CERT_FILE="\K[^"]*' "$SCRIPTS_DIR/config.sh" 2>/dev/null)
    local VSFTPD_KEY_FILE_PATH=$(grep -oP '^VSFTPD_KEY_FILE="\K[^"]*' "$SCRIPTS_DIR/config.sh" 2>/dev/null)

    VSFTPD_CERT_FILE_PATH=${VSFTPD_CERT_FILE_PATH:-/etc/ssl/private/vsftpd.pem}
    VSFTPD_KEY_FILE_PATH=${VSFTPD_KEY_FILE_PATH:-/etc/ssl/private/vsftpd.pem}

    echo -ne "${CYAN}▹ ${RESET}Creating vsftpd configuration... "
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
    echo -e "${BRIGHT_GREEN}Done ✓${RESET}"

    echo -ne "${CYAN}▹ ${RESET}Creating SSL certificate directory... "
    if [ ! -d "$(dirname "$VSFTPD_CERT_FILE_PATH")" ]; then
        mkdir -p "$(dirname "$VSFTPD_CERT_FILE_PATH")"
        if [ $? -ne 0 ]; then 
            echo -e "${RED}Failed ✗${RESET}"
            echo_error "Failed to create directory for SSL certificate: $(dirname "$VSFTPD_CERT_FILE_PATH")"
            return 1
        fi
    fi
    echo -e "${BRIGHT_GREEN}Done ✓${RESET}"

    echo_info "Generating self-signed SSL certificate for vsftpd"
    echo -e "${BRIGHT_BLUE}Certificate will be stored at:${RESET} $VSFTPD_CERT_FILE_PATH"
    echo -e "${YELLOW}Please provide the following details for the SSL certificate:${RESET}"
    echo

    # Certificate details input with colored prompts
    local country_code state_province locality_name org_name cn_name
    echo -ne "${CYAN}▹ ${RESET}${BOLD}Country Name${RESET} (2 letter code) [${DIM}XX${RESET}]: "
    read -r country_code
    country_code=${country_code:-XX}
    
    echo -ne "${CYAN}▹ ${RESET}${BOLD}State or Province${RESET} (full name) [${DIM}DefaultState${RESET}]: "
    read -r state_province
    state_province=${state_province:-DefaultState}
    
    echo -ne "${CYAN}▹ ${RESET}${BOLD}Locality Name${RESET} (eg, city) [${DIM}DefaultCity${RESET}]: "
    read -r locality_name
    locality_name=${locality_name:-DefaultCity}
    
    echo -ne "${CYAN}▹ ${RESET}${BOLD}Organization Name${RESET} (eg, company) [${DIM}DefaultCompany${RESET}]: "
    read -r org_name
    org_name=${org_name:-DefaultCompany}
    
    echo -ne "${CYAN}▹ ${RESET}${BOLD}Common Name${RESET} (e.g. server FQDN) [${DIM}ftp.example.com${RESET}]: "
    read -r cn_name
    cn_name=${cn_name:-ftp.example.com}

    local subj_str="/C=$country_code/ST=$state_province/L=$locality_name/O=$org_name/CN=$cn_name"
    echo -e "${GRAY}Using subject:${RESET} $subj_str"
    echo

    echo -ne "${CYAN}▹ ${RESET}Generating SSL certificate... "
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
        -keyout "$VSFTPD_KEY_FILE_PATH" -out "$VSFTPD_CERT_FILE_PATH" \
        -subj "$subj_str" > /dev/null 2>&1
        
    if [ $? -ne 0 ]; then 
        echo -e "${RED}Failed ✗${RESET}"
        echo_error "Failed to generate SSL certificate."
        return 1
    fi
    
    chmod 600 "$VSFTPD_KEY_FILE_PATH" "$VSFTPD_CERT_FILE_PATH"
    echo -e "${BRIGHT_GREEN}Done ✓${RESET}"

    echo -ne "${CYAN}▹ ${RESET}Creating secure chroot directory... "
    if [ ! -d /var/run/vsftpd/empty ]; then mkdir -p /var/run/vsftpd/empty; fi
    if [ $? -ne 0 ]; then 
        echo -e "${RED}Failed ✗${RESET}"
        echo_error "Failed to create /var/run/vsftpd/empty."
        return 1
    fi
    echo -e "${BRIGHT_GREEN}Done ✓${RESET}"

    echo -ne "${CYAN}▹ ${RESET}Restarting vsftpd service... "
    systemctl restart vsftpd > /dev/null 2>&1
    if [ $? -ne 0 ]; then 
        echo -e "${RED}Failed ✗${RESET}"
        echo_error "Failed to restart vsftpd. Check 'journalctl -u vsftpd' or '/var/log/vsftpd.log'."
        return 1
    fi
    echo -e "${BRIGHT_GREEN}Done ✓${RESET}"
    
    echo -ne "${CYAN}▹ ${RESET}Enabling vsftpd service on boot... "
    systemctl enable vsftpd > /dev/null 2>&1
    if [ $? -ne 0 ]; then 
        echo -e "${YELLOW}Warning ⚠${RESET}"
        echo_warn "Failed to enable vsftpd to start on boot."
    else
        echo -e "${BRIGHT_GREEN}Done ✓${RESET}"
    fi

    echo_success "vsftpd configuration complete."
    echo -e "${YELLOW}Note:${RESET} If using a firewall, ensure ports 20, 21, and passive ports are open."
}

configure_logrotate() {
    show_section_header "Configuring Log Rotation"
    echo_info "Setting up log rotation policies..."
    
    local user_mgmt_freq=$(grep -oP '^LOGROTATE_USER_MGMT_FREQUENCY="\K[^"]*' "$SCRIPTS_DIR/config.sh" 2>/dev/null)
    local user_mgmt_keep=$(grep -oP '^LOGROTATE_USER_MGMT_KEEP="\K[^"]*' "$SCRIPTS_DIR/config.sh" 2>/dev/null)
    local reports_freq=$(grep -oP '^LOGROTATE_SECURITY_REPORTS_FREQUENCY="\K[^"]*' "$SCRIPTS_DIR/config.sh" 2>/dev/null)
    local reports_keep=$(grep -oP '^LOGROTATE_SECURITY_REPORTS_KEEP="\K[^"]*' "$SCRIPTS_DIR/config.sh" 2>/dev/null)

    user_mgmt_freq=${user_mgmt_freq:-weekly}
    user_mgmt_keep=${user_mgmt_keep:-4}
    reports_freq=${reports_freq:-daily}
    reports_keep=${reports_keep:-30}

    echo -ne "${CYAN}▹ ${RESET}Configuring user management logs rotation (${BOLD}${user_mgmt_freq}${RESET}, keep ${BOLD}${user_mgmt_keep}${RESET})... "
    local logrotate_user_mgmt_tpl="$CONFIG_DIR_DEST/logrotate_user_mgmt"
    local logrotate_user_mgmt_final="$LOGROTATE_CONF_DIR/secure_system_user_mgmt"
    cp "$logrotate_user_mgmt_tpl" "$logrotate_user_mgmt_final" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        sed -i "s/^    weekly/    $user_mgmt_freq/" "$logrotate_user_mgmt_final"
        sed -i "s/^    rotate 4/    rotate $user_mgmt_keep/" "$logrotate_user_mgmt_final"
        
        # Update log path in template if necessary
        local user_mgmt_log_path_for_rotate=$(grep -oP '^USER_MGMT_LOG="\K[^"]*' "$SCRIPTS_DIR/config.sh" 2>/dev/null)
        user_mgmt_log_path_for_rotate=${user_mgmt_log_path_for_rotate:-/var/log/user_mgmt.log}
        sed -i "s|^/var/log/user_mgmt.log|$user_mgmt_log_path_for_rotate|" "$logrotate_user_mgmt_final"
        
        echo -e "${BRIGHT_GREEN}Done ✓${RESET}"
    else
        echo -e "${RED}Failed ✗${RESET}"
        echo_error "Failed to copy user management logrotate template."
    fi

    echo -ne "${CYAN}▹ ${RESET}Configuring security reports rotation (${BOLD}${reports_freq}${RESET}, keep ${BOLD}${reports_keep}${RESET})... "
    local logrotate_reports_tpl="$CONFIG_DIR_DEST/logrotate_security_reports"
    local logrotate_reports_final="$LOGROTATE_CONF_DIR/secure_system_security_reports"
    cp "$logrotate_reports_tpl" "$logrotate_reports_final" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        sed -i "s/^    daily/    $reports_freq/" "$logrotate_reports_final"
        sed -i "s/^    rotate 30/    rotate $reports_keep/" "$logrotate_reports_final"
        
        local security_reports_dir_for_rotate=$(grep -oP '^SECURITY_REPORT_DIR="\K[^"]*' "$SCRIPTS_DIR/config.sh" 2>/dev/null)
        security_reports_dir_for_rotate=${security_reports_dir_for_rotate:-/var/log/security_reports}
        sed -i "s|^/var/log/security_reports/\*.txt|$security_reports_dir_for_rotate/*.txt|" "$logrotate_reports_final"
        
        echo -e "${BRIGHT_GREEN}Done ✓${RESET}"
    else
        echo -e "${RED}Failed ✗${RESET}"
        echo_error "Failed to copy security reports logrotate template."
    fi

    echo_success "Log rotation configured successfully."
}

configure_cron_jobs() {
    show_section_header "Setting Up Scheduled Tasks"
    
    if [ "$SKIP_CRON_SETUP" = true ]; then
        echo_info "Skipping cron job setup as per earlier choice."
        echo_warn "Manual cron setup required for daily log analysis: 0 0 * * * $SCRIPTS_DIR/log_analysis.sh"
        return 0
    fi
    
    echo_info "Configuring cron job for daily log analysis..."
    local log_analysis_cmd="$SCRIPTS_DIR/log_analysis.sh"
    
    echo -ne "${CYAN}▹ ${RESET}Adding daily scheduled task (midnight)... "
    (crontab -l 2>/dev/null | grep -v -F "$log_analysis_cmd" ; echo "0 0 * * * $log_analysis_cmd") | crontab -
    
    if [ $? -eq 0 ]; then
        echo -e "${BRIGHT_GREEN}Done ✓${RESET}"
        echo_success "Cron job for daily log analysis scheduled successfully."
        echo -e "${GRAY}Verify with:${RESET} sudo crontab -l"
    else
        echo -e "${RED}Failed ✗${RESET}"
        echo_error "Failed to schedule cron job for log analysis."
        echo -e "${YELLOW}Manually add:${RESET} 0 0 * * * $log_analysis_cmd"
    fi
}

configure_bonus_features_interactive() {
    show_section_header "Configuring Bonus Features"
    echo_info "Configuring advanced features (Optional)..."
    
    local config_script_path="$SCRIPTS_DIR/config.sh"
    local admin_email_val=""

    # Email reporting configuration with styled UI
    echo -e "${BRIGHT_WHITE}${BOLD}━━ Email Reporting ━━${RESET}"
    if ask_yes_no "Enable daily security reports via email?" "n"; then
        echo -ne "${CYAN}▹ ${RESET}Enabling email reporting... "
        sed -i 's/^SEND_EMAIL_REPORTS=.*/SEND_EMAIL_REPORTS="true"/' "$config_script_path"
        echo -e "${BRIGHT_GREEN}Enabled ✓${RESET}"
        
        if ! command -v mail &> /dev/null && ! command -v mailx &> /dev/null; then
            echo_warn "'mailutils' package (provides 'mail' command) is required for sending emails."
            if ask_yes_no "Install mailutils now?" "y"; then
                echo -ne "${CYAN}▹ ${RESET}Installing mailutils... "
                apt update > /dev/null 2>&1 && apt install -y mailutils > /dev/null 2>&1
                
                if [ $? -eq 0 ]; then
                    echo -e "${BRIGHT_GREEN}Success ✓${RESET}"
                else
                    echo -e "${RED}Failed ✗${RESET}"
                    echo_error "Failed to install mailutils. Email reporting might fail."
                fi
            else
                echo_warn "mailutils not installed by choice. Email reporting might fail."
            fi
        fi
        
        echo -e "${YELLOW}Configure administrator email for receiving reports:${RESET}"
        while true; do
            echo -ne "${CYAN}▹ ${RESET}${BOLD}Administrator Email${RESET} [${DIM}${DEFAULT_ADMIN_EMAIL}${RESET}]: "
            read -r admin_email_val
            admin_email_val=${admin_email_val:-$DEFAULT_ADMIN_EMAIL}
            
            if [[ "$admin_email_val" == "" || "$admin_email_val" != *@* ]]; then
                echo -e "${RED}⚠ Invalid email format. Please enter a valid email address.${RESET}"
            else
                echo -ne "${CYAN}▹ ${RESET}Setting administrator email... "
                # Escape for sed
                local escaped_admin_email_val=$(printf '%s\n' "$admin_email_val" | sed 's:[\/&]:\\&:g')
                sed -i "s|^ADMIN_EMAIL=.*|ADMIN_EMAIL=\"$escaped_admin_email_val\"|" "$config_script_path"
                echo -e "${BRIGHT_GREEN}Done ✓${RESET}"
                break
            fi
        done
    else
        echo -ne "${CYAN}▹ ${RESET}Disabling email reporting... "
        sed -i 's/^SEND_EMAIL_REPORTS=.*/SEND_EMAIL_REPORTS="false"/' "$config_script_path"
        sed -i 's/^ADMIN_EMAIL=.*/ADMIN_EMAIL=""/' "$config_script_path"
        echo -e "${GRAY}Disabled ✓${RESET}"
    fi
    
    echo
    
    # Weekly summary configuration
    echo -e "${BRIGHT_WHITE}${BOLD}━━ Weekly Reports ━━${RESET}"
    if ask_yes_no "Include weekly summary of failed logins in daily reports?" "n"; then
        echo -ne "${CYAN}▹ ${RESET}Enabling weekly summary... "
        sed -i 's/^INCLUDE_WEEKLY_SUMMARY=.*/INCLUDE_WEEKLY_SUMMARY="true"/' "$config_script_path"
        echo -e "${BRIGHT_GREEN}Enabled ✓${RESET}"
    else
        echo -ne "${CYAN}▹ ${RESET}Disabling weekly summary... "
        sed -i 's/^INCLUDE_WEEKLY_SUMMARY=.*/INCLUDE_WEEKLY_SUMMARY="false"/' "$config_script_path"
        echo -e "${GRAY}Disabled ✓${RESET}"
    fi
    
    echo
    
    # Account locking configuration
    echo -e "${BRIGHT_WHITE}${BOLD}━━ Account Security ━━${RESET}"
    if ask_yes_no "Enable automatic account locking check (conceptual feature in reports)?" "n"; then
        echo -ne "${CYAN}▹ ${RESET}Enabling account locking check... "
        sed -i 's/^ENABLE_ACCOUNT_LOCKING=.*/ENABLE_ACCOUNT_LOCKING="true"/' "$config_script_path"
        echo -e "${BRIGHT_GREEN}Enabled ✓${RESET}"
        
        local max_fails_val
        echo -ne "${CYAN}▹ ${RESET}${BOLD}Max Failed Attempts${RESET} before account is flagged [${DIM}5${RESET}]: "
        read -r max_fails_val
        max_fails_val=${max_fails_val:-5}
        
        if ! [[ "$max_fails_val" =~ ^[0-9]+$ ]]; then
            max_fails_val=5
            echo_warn "Invalid input, using default value of 5."
        fi
        
        echo -ne "${CYAN}▹ ${RESET}Setting max failed attempts threshold... "
        sed -i "s/^MAX_FAILED_ATTEMPTS=.*/MAX_FAILED_ATTEMPTS=$max_fails_val/" "$config_script_path"
        echo -e "${BRIGHT_GREEN}Done ($max_fails_val) ✓${RESET}"
        
        echo -e "${YELLOW}Note:${RESET} Account locking check in log_analysis.sh is illustrative. For production, use pam_tally2 or fail2ban."
    else
        echo -ne "${CYAN}▹ ${RESET}Disabling account locking check... "
        sed -i 's/^ENABLE_ACCOUNT_LOCKING=.*/ENABLE_ACCOUNT_LOCKING="false"/' "$config_script_path"
        echo -e "${GRAY}Disabled ✓${RESET}"
    fi

    echo_success "Bonus features configured successfully."
}

show_completion_message() {
    show_section_header "Installation Complete"
    
    echo -e "${BRIGHT_GREEN}${BOLD}✅ Secure User & Log Management System has been successfully installed!${RESET}"
    echo
    echo -e "${BRIGHT_WHITE}${BOLD}System Information:${RESET}"
    echo -e "${CYAN}▸ ${RESET}${BOLD}Main Interface:${RESET}        $SCRIPTS_DIR/secure_system.sh"
    echo -e "${CYAN}▸ ${RESET}${BOLD}Configuration:${RESET}         $SCRIPTS_DIR/config.sh"
    echo -e "${CYAN}▸ ${RESET}${BOLD}User Management Logs:${RESET}  $(grep -oP '^USER_MGMT_LOG="\K[^"]*' "$SCRIPTS_DIR/config.sh" 2>/dev/null || echo "/var/log/user_mgmt.log")"
    echo -e "${CYAN}▸ ${RESET}${BOLD}Security Reports:${RESET}      $(grep -oP '^SECURITY_REPORT_DIR="\K[^"]*' "$SCRIPTS_DIR/config.sh" 2>/dev/null || echo "/var/log/security_reports")"
    
    echo
    echo -e "${BRIGHT_WHITE}${BOLD}Getting Started:${RESET}"
    echo -e "${CYAN}1.${RESET} Run the main interface:  ${GREEN}sudo $SCRIPTS_DIR/secure_system.sh${RESET}"
    echo -e "${CYAN}2.${RESET} Verify cron job:         ${GREEN}sudo crontab -l${RESET}"
    echo -e "${CYAN}3.${RESET} Review configuration:    ${GREEN}nano $SCRIPTS_DIR/config.sh${RESET}"
    
    echo
    echo -e "${YELLOW}Note:${RESET} If FTP is being used, ensure firewall rules are set to allow traffic on ports 20, 21,"
    echo -e "      and the passive port range if configured."
    echo
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

# --- Main Installation Logic ---
main() {
    show_logo
    echo_info "Starting Secure User & Log Management System installation..."
    sleep 1
    
    check_root
    check_dependencies
    
    create_directories
    copy_files
    
    configure_vsftpd
    configure_logrotate
    configure_cron_jobs
    
    # Interactive configuration of bonus features
    configure_bonus_features_interactive
    
    # Show completion message and next steps
    show_completion_message
}

main

exit 0

