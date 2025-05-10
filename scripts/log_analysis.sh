#!/bin/bash

# Script for Secure Log Analysis (Core + Bonus Features)
# Analyzes /var/log/auth.log for failed login attempts, generates daily reports,
# and handles bonus features like email reports, weekly summaries, and account locking.

# Source colors and styling
SCRIPT_DIR="$(dirname "$0")"
if [ -f "$SCRIPT_DIR/colors.sh" ]; then
    source "$SCRIPT_DIR/colors.sh"
else
    echo "Error: colors.sh not found. Styling will be unavailable." >&2
    # Define minimal styling for critical functionality
    RESET="\e[0m"
    RED="\e[31m"
    BOLD="\e[1m"
fi

# Source configuration
CONFIG_FILE="$SCRIPT_DIR/config.sh"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo -e "${RED}[${BOLD}ERROR${RESET}${RED}]${RESET} Configuration file $CONFIG_FILE not found." >&2
    exit 1
fi

# Variables from config (or defaults if not set)
AUTH_LOG="${AUTH_LOG_FILE:-/var/log/auth.log}"
REPORT_DIR="${SECURITY_REPORT_DIR:-/var/log/security_reports}"
SEND_EMAIL="${SEND_EMAIL_REPORTS:-false}"
ADMIN_EMAIL_ADDR="${ADMIN_EMAIL:-}"
INCLUDE_WEEKLY="${INCLUDE_WEEKLY_SUMMARY:-false}"
LOCK_ACCOUNTS="${ENABLE_ACCOUNT_LOCKING:-false}"
MAX_FAILS="${MAX_FAILED_ATTEMPTS:-5}"
# ACCOUNT_LOCK_DURATION is for reference in config, actual locking handled by pam_tally2 or fail2ban ideally.

TODAY=$(date +"%Y-%m-%d")
REPORT_FILE="$REPORT_DIR/failed_logins_report_$TODAY.txt"
TEMP_FAILED_LOGINS_IP="/tmp/failed_logins_ip_temp_$TODAY.txt"
TEMP_FAILED_LOGINS_USER="/tmp/failed_logins_user_temp_$TODAY.txt"

# --- Helper Functions ---

# Show fancy ASCII art logo
show_logo() {
    clear
    echo -e "${CYAN}"
    echo -e " ██╗      ██████╗  ██████╗      █████╗ ███╗   ██╗ █████╗ ██╗  ██╗   ██╗███████╗██╗███████╗"
    echo -e " ██║     ██╔═══██╗██╔════╝     ██╔══██╗████╗  ██║██╔══██╗██║  ╚██╗ ██╔╝██╔════╝██║██╔════╝"
    echo -e " ██║     ██║   ██║██║  ███╗    ███████║██╔██╗ ██║███████║██║   ╚████╔╝ ███████╗██║███████╗"
    echo -e " ██║     ██║   ██║██║   ██║    ██╔══██║██║╚██╗██║██╔══██║██║    ╚██╔╝  ╚════██║██║╚════██║"
    echo -e " ███████╗╚██████╔╝╚██████╔╝    ██║  ██║██║ ╚████║██║  ██║███████╗██║   ███████║██║███████║"
    echo -e " ╚══════╝ ╚═════╝  ╚═════╝     ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝╚══════╝╚═╝   ╚══════╝╚═╝╚══════╝"
    echo -e "${BRIGHT_BLUE}                                                                              v1.0.0"
    echo -e "${RESET}${BOLD}${BRIGHT_WHITE}                       SECURE LOG ANALYSIS ENGINE${RESET}"
    echo -e "${DIM}                            Analyzing Security Threats${RESET}"
    echo
    divider
    echo
}

# Spinner animation for long operations
spinner() {
    local delay=0.1
    local spinstr='|/-\'
    while true; do
        for i in $(seq 0 3); do
            local temp=${spinstr:$i:1}
            echo -en "\r${CYAN}▹ ${RESET}${1}... ${BRIGHT_CYAN}[${temp}]${RESET}  "
            sleep $delay
        done
    done
}

# Progress bar
progress_bar() {
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

log_message() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - log_analysis.sh - $1" >> "/var/log/secure-system.log"
    if [ "$2" = "verbose" ]; then
        echo -e "${GRAY}$(date +'%H:%M:%S')${RESET} $1"
    fi
}

setup_report_dir() {
    if [ ! -d "$REPORT_DIR" ]; then
        echo -ne "${CYAN}▹ ${RESET}Creating report directory ${BOLD}$REPORT_DIR${RESET}... "
        mkdir -p "$REPORT_DIR"
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed ✗${RESET}"
            log_message "Error: Could not create report directory $REPORT_DIR."
            exit 1
        fi
        chmod 750 "$REPORT_DIR"
        chown root:adm "$REPORT_DIR" 2>/dev/null || chown root:root "$REPORT_DIR" 2>/dev/null
        echo -e "${BRIGHT_GREEN}Done ✓${RESET}"
        log_message "Report directory $REPORT_DIR created successfully."
    else
        echo -e "${CYAN}▹ ${RESET}Report directory ${BOLD}$REPORT_DIR${RESET} already exists ${BRIGHT_GREEN}✓${RESET}"
    fi
}

check_log_readable() {
    echo -ne "${CYAN}▹ ${RESET}Checking access to log file ${BOLD}$1${RESET}... "
    if [ ! -r "$1" ]; then
        echo -e "${RED}Failed ✗${RESET}"
        echo_error "Cannot read log file $1. Check permissions or if the file exists."
        log_message "Error: Cannot read log file $1. Check permissions or if file exists."
        exit 1
    fi
    echo -e "${BRIGHT_GREEN}Access granted ✓${RESET}"
    return 0
}

# --- Core Log Analysis Function ---

generate_failed_login_report_core() {
    show_section_header "Failed Login Analysis"
    echo_info "Analyzing failed login attempts for ${BRIGHT_WHITE}$TODAY${RESET}..."
    check_log_readable "$AUTH_LOG"

    # Start the spinner in the background
    echo -ne "${CYAN}▹ ${RESET}Processing log data... "
    
    # Create the report header
    {
        echo "Security Report - Failed Login Attempts - $TODAY"
        echo "======================================================"
        echo "Generated on: $(date)"
        echo "Analysis based on log file: $AUTH_LOG"
        echo ""
    } > "$REPORT_FILE" # Overwrite or create the report file

    current_month_day_pattern=$(date +"%b %_d") 
    current_month_day_pattern_alt=$(date +"%b %d")

    # Count failed password attempts by IP for today
    grep "Failed password" "$AUTH_LOG" |
        grep -E "($current_month_day_pattern|$current_month_day_pattern_alt)" |
        grep -oE "from ([0-9]{1,3}\.){3}[0-9]{1,3}" | awk '{print $2}' | sort | uniq -c | sort -nr > "$TEMP_FAILED_LOGINS_IP"

    # Simulate progress delay for better UX
    for i in $(seq 10 10 100); do
        sleep 0.1
        progress_bar $i
    done
    echo -e "\r${CYAN}▹ ${RESET}Processing log data... ${BRIGHT_GREEN}Complete ✓${RESET}    "

    echo -ne "${CYAN}▹ ${RESET}Generating IP-based analysis... "
    if [ ! -s "$TEMP_FAILED_LOGINS_IP" ]; then
        echo "No failed login attempts recorded today for IP addresses (matching date pattern: $current_month_day_pattern or $current_month_day_pattern_alt)." >> "$REPORT_FILE"
        echo -e "${BRIGHT_YELLOW}No attempts found ⚠${RESET}"
    else
        echo "Failed password attempts by IP address (Today - matching date pattern: $current_month_day_pattern or $current_month_day_pattern_alt):" >> "$REPORT_FILE"
        while IFS= read -r line; do
            count=$(echo "$line" | awk '{print $1}')
            ip=$(echo "$line" | awk '{print $2}')
            echo "  IP: $ip - $count attempts" >> "$REPORT_FILE"
        done < "$TEMP_FAILED_LOGINS_IP"

        echo "" >> "$REPORT_FILE"
        echo "Most recent failed attempt from each IP (Today - matching date pattern):" >> "$REPORT_FILE"
        awk '{print $2}' "$TEMP_FAILED_LOGINS_IP" | sort -u | while IFS= read -r ip; do
            latest_attempt_line=$(grep "Failed password" "$AUTH_LOG" | grep -E "($current_month_day_pattern|$current_month_day_pattern_alt)" | grep "from $ip" | tail -1)
            if [ -n "$latest_attempt_line" ]; then
                timestamp=$(echo "$latest_attempt_line" | awk '{print $1,$2,$3}')
                user_info=$(echo "$latest_attempt_line" | sed -n 's/.*Failed password for \(invalid user \S\+\|\S\+\).*/\1/p')
                echo "  IP: $ip - User: ${user_info:-(unknown)} - Last attempt: $timestamp" >> "$REPORT_FILE"
            fi
        done
        echo -e "${BRIGHT_GREEN}Done ✓${RESET}"
    fi

    total_today_count=$(grep "Failed password" "$AUTH_LOG" | grep -E "($current_month_day_pattern|$current_month_day_pattern_alt)" | wc -l)
    echo "" >> "$REPORT_FILE"
    echo "Total failed login attempts (Today - matching date pattern: $current_month_day_pattern or $current_month_day_pattern_alt): $total_today_count" >> "$REPORT_FILE"

    if [ $total_today_count -gt 0 ]; then
        echo -e "${CYAN}▹ ${RESET}Statistics: ${BRIGHT_YELLOW}${BOLD}$total_today_count${RESET} failed login attempts detected today"
        echo -e "${CYAN}▹ ${RESET}From ${BRIGHT_YELLOW}${BOLD}$(wc -l < "$TEMP_FAILED_LOGINS_IP")${RESET} unique IP addresses"
    else
        echo -e "${CYAN}▹ ${RESET}Statistics: ${BRIGHT_GREEN}No failed login attempts detected today${RESET}"
    fi

    log_message "Core failed login report section generated successfully."
}

# --- Bonus Feature Functions ---

generate_weekly_summary() {
    if [ "$INCLUDE_WEEKLY" = "true" ]; then
        show_section_header "Weekly Summary Analysis"
        echo_info "Generating weekly summary of failed login attempts..."
        
        echo -ne "${CYAN}▹ ${RESET}Analyzing logs from the past week... "
        
        echo "" >> "$REPORT_FILE"
        echo "Weekly Summary - Failed Login Attempts (Last 7 Days, excluding today):" >> "$REPORT_FILE"
        echo "---------------------------------------------------------------------" >> "$REPORT_FILE"
        
        local total_weekly_fails=0
        
        # Start progress bar
        echo
        for i in $(seq 1 7); do
            local percentage=$((i * 14))
            progress_bar $percentage
            
            day_to_check_date_format=$(date -d "$TODAY -$i days" +"%b %_d") # Format like "May  1"
            day_to_check_date_format_alt=$(date -d "$TODAY -$i days" +"%b %d") # Format like "May 01"
            day_display_format=$(date -d "$TODAY -$i days" +"%Y-%m-%d (%a)")
            
            # This grep is simplified; for accuracy across log rotations, more advanced parsing of auth.log, auth.log.1, auth.log.2.gz etc. is needed.
            # For this script, we search current AUTH_LOG and common rotated log names.
            daily_fail_count=$(grep "Failed password" "$AUTH_LOG"* "${AUTH_LOG%.*}.1" "${AUTH_LOG%.*}*.gz" 2>/dev/null | 
                               grep -E "($day_to_check_date_format|$day_to_check_date_format_alt)" | wc -l)
            sleep 0.2 # Slight delay for visual effect
            echo "  $day_display_format: $daily_fail_count failed attempts" >> "$REPORT_FILE"
            total_weekly_fails=$((total_weekly_fails + daily_fail_count))
        done
        progress_bar 100
        echo -e "\n${CYAN}▹ ${RESET}Weekly analysis complete ${BRIGHT_GREEN}✓${RESET}"
        
        echo "Total failed attempts in the past 7 days (approximate, from available logs): $total_weekly_fails" >> "$REPORT_FILE"
        echo "Note: Weekly summary accuracy depends on availability and parsing of older/rotated log data." >> "$REPORT_FILE"
        
        echo -e "${CYAN}▹ ${RESET}Weekly statistics: ${BRIGHT_YELLOW}${BOLD}$total_weekly_fails${RESET} failed attempts in the past 7 days"
        
        log_message "Weekly summary analysis complete with $total_weekly_fails total failed attempts."
    else
        log_message "Weekly summary analysis skipped (disabled in configuration)."
    fi
}

handle_account_locking_check() {
    if [ "$LOCK_ACCOUNTS" = "true" ]; then
        show_section_header "Account Security Analysis"
        echo_info "Checking for accounts with excessive failed login attempts..."
        
        echo -ne "${CYAN}▹ ${RESET}Identifying vulnerable accounts... "
        
        echo "" >> "$REPORT_FILE"
        echo "Account Locking Check (Conceptual - based on today's logs):" >> "$REPORT_FILE"
        echo "------------------------------------------------------------" >> "$REPORT_FILE"

        current_month_day_pattern=$(date +"%b %_d")
        current_month_day_pattern_alt=$(date +"%b %d")

        # Extract usernames from today's failed password attempts
        grep "Failed password for" "$AUTH_LOG" |
            grep -E "($current_month_day_pattern|$current_month_day_pattern_alt)" |
            sed -n -E 's/.*Failed password for (invalid user )?(\S+).*/\2/p' | 
            grep -vE "^from$" | sort | uniq -c | sort -nr > "$TEMP_FAILED_LOGINS_USER"

        if [ ! -s "$TEMP_FAILED_LOGINS_USER" ]; then
            echo "No user-specific failed login attempts found today to check for locking." >> "$REPORT_FILE"
            echo -e "${BRIGHT_GREEN}No vulnerable accounts found ✓${RESET}"
        else
            local user_locked_info_exists=false
            local alert_count=0
            
            echo -e "${BRIGHT_GREEN}Done ✓${RESET}"
            echo -e "${CYAN}▹ ${RESET}Analyzing threshold violations..."
            
            while IFS= read -r line; do
                count=$(echo "$line" | awk '{print $1}')
                user=$(echo "$line" | awk '{print $2}')
                
                if [ -z "$user" ]; then continue; fi

                if [ "$count" -ge "$MAX_FAILS" ]; then
                    alert_count=$((alert_count + 1))
                    log_message "ALERT: User '$user' has $count failed login attempts today, exceeding limit of $MAX_FAILS."
                    echo "  ALERT: User '$user' has $count failed login attempts today. Policy: Lock if >= $MAX_FAILS attempts." >> "$REPORT_FILE"
                    echo "         Action: For production, configure pam_tally2 or fail2ban for actual locking." >> "$REPORT_FILE"
                    user_locked_info_exists=true
                    echo -e "  ${BRIGHT_RED}⚠ ${BOLD}ALERT:${RESET} User ${BRIGHT_WHITE}'$user'${RESET} has ${BRIGHT_RED}$count${RESET} failed attempts (threshold: $MAX_FAILS)"
                fi
            done < "$TEMP_FAILED_LOGINS_USER"
            
            if [ "$alert_count" -eq 0 ]; then
                echo -e "${BRIGHT_GREEN}No threshold violations found ✓${RESET}"
            fi
            
            if [ "$user_locked_info_exists" = false ]; then
                 echo "No users met or exceeded the $MAX_FAILS failed attempts threshold today." >> "$REPORT_FILE"
            fi
        fi
        echo "Note: This script only reports potential accounts for locking. Actual locking requires tools like pam_tally2 or fail2ban." >> "$REPORT_FILE"
        
        log_message "Account locking check completed successfully."
    else
        log_message "Account locking check skipped (disabled in configuration)."
    fi
}

send_report_by_email() {
    if [ "$SEND_EMAIL" = "true" ]; then
        show_section_header "Email Notification"
        echo_info "Preparing to send report by email..."
        
        if [ -z "$ADMIN_EMAIL_ADDR" ]; then
            echo_error "Admin email address (ADMIN_EMAIL) is not configured in config.sh. Cannot send email report."
            echo "Error: Admin email address not set. Cannot send email." >> "$REPORT_FILE"
            log_message "Error: Admin email address not set. Email notification skipped."
            return 1
        fi
        
        echo -ne "${CYAN}▹ ${RESET}Checking for mail utilities... "
        if ! command -v mail &> /dev/null && ! command -v mailx &> /dev/null ; then 
            echo -e "${RED}Not found ✗${RESET}"
            echo_error "'mail' command (from mailutils) not found. Cannot send email report."
            echo "Error: 'mail' command not found. Please install mailutils." >> "$REPORT_FILE"
            log_message "Error: 'mail' command not found. Email notification skipped."
            return 1
        fi
        echo -e "${BRIGHT_GREEN}Found ✓${RESET}"

        local subject="Security Report: Failed Logins - $TODAY"
        if [ ! -s "$REPORT_FILE" ]; then
            echo -ne "${CYAN}▹ ${RESET}Report is empty, sending 'no incidents' notification... "
            echo "Daily security report for $TODAY was generated but contained no relevant failed login entries." | mail -s "Security Report: No Failed Login Incidents - $TODAY" "$ADMIN_EMAIL_ADDR"
            if [ $? -eq 0 ]; then
                echo -e "${BRIGHT_GREEN}Sent ✓${RESET}"
                log_message "'No incidents' email successfully sent to $ADMIN_EMAIL_ADDR."
            else
                echo -e "${RED}Failed ✗${RESET}"
                log_message "Error: Failed to send 'no incidents' email to $ADMIN_EMAIL_ADDR."
            fi
            return
        fi
        
        # Append a note about the email to the report itself for audit
        echo "" >> "$REPORT_FILE"
        echo "--- Email Notification --- " >> "$REPORT_FILE"
        echo "This report was scheduled to be emailed to: $ADMIN_EMAIL_ADDR" >> "$REPORT_FILE"

        echo -ne "${CYAN}▹ ${RESET}Sending report to ${BOLD}$ADMIN_EMAIL_ADDR${RESET}... "
        cat "$REPORT_FILE" | mail -s "$subject" "$ADMIN_EMAIL_ADDR"
        if [ $? -eq 0 ]; then
            echo -e "${BRIGHT_GREEN}Sent ✓${RESET}"
            log_message "Security report successfully sent to $ADMIN_EMAIL_ADDR."
            echo "Email Status: Successfully sent." >> "$REPORT_FILE"
        else
            echo -e "${RED}Failed ✗${RESET}"
            echo_error "Failed to send security report to $ADMIN_EMAIL_ADDR. Check mail system logs."
            log_message "Error: Failed to send security report to $ADMIN_EMAIL_ADDR."
            echo "Email Status: FAILED to send. Check system mail logs." >> "$REPORT_FILE"
        fi
    else
        log_message "Email notification skipped (disabled in configuration)."
    fi
}

finalize_report() {
    echo -ne "${CYAN}▹ ${RESET}Setting final report permissions... "
    chmod 640 "$REPORT_FILE"
    if [ $? -eq 0 ]; then
        echo -e "${BRIGHT_GREEN}Done ✓${RESET}"
    else
        echo -e "${YELLOW}Warning ⚠${RESET}"
        echo_warn "Could not set proper permissions on report file."
    fi
    
    # Clean up temporary files
    echo -ne "${CYAN}▹ ${RESET}Cleaning up temporary files... "
    rm -f "$TEMP_FAILED_LOGINS_IP" "$TEMP_FAILED_LOGINS_USER"
    echo -e "${BRIGHT_GREEN}Done ✓${RESET}"
    
    echo_success "Log analysis complete. Report saved to: ${UNDERLINE}$REPORT_FILE${RESET}"
}

# --- Main Execution (Core + Bonus) ---

main() {
    show_logo
    echo_info "Starting security log analysis for ${BRIGHT_WHITE}$TODAY${RESET}..."
    
    # Record script execution to log
    log_message "Log analysis script started (with bonus features check)."
    
    # Setup
    setup_report_dir
    
    # Core analysis
    generate_failed_login_report_core
    
    # Bonus features
    if [ "$INCLUDE_WEEKLY" = "true" ]; then
        generate_weekly_summary
    fi
    
    if [ "$LOCK_ACCOUNTS" = "true" ]; then
        handle_account_locking_check
    fi
    
    # Email notification
    if [ "$SEND_EMAIL" = "true" ]; then
        send_report_by_email
    fi
    
    # Finalize
    finalize_report
    
    show_section_header "Analysis Complete"
    echo -e "${GRAY}Report generation finished at:${RESET} ${BRIGHT_WHITE}$(date)${RESET}"
    echo -e "${GRAY}Report saved to:${RESET} ${BRIGHT_WHITE}$REPORT_FILE${RESET}"
    
    log_message "Log analysis script completed successfully."
    exit 0
}

# Run main function
main

