#!/bin/bash

# Script for Secure Log Analysis (Core + Bonus Features)
# Analyzes /var/log/auth.log for failed login attempts, generates daily reports,
# and handles bonus features like email reports, weekly summaries, and account locking.

# Source configuration
CONFIG_FILE="$(dirname "$(readlink -f "$0")")/config.sh"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "Error: Configuration file $CONFIG_FILE not found." >&2
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

log_message() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - log_analysis.sh - $1"
}

setup_report_dir() {
    if [ ! -d "$REPORT_DIR" ]; then
        mkdir -p "$REPORT_DIR"
        if [ $? -ne 0 ]; then
            log_message "Error: Could not create report directory $REPORT_DIR." >&2
            exit 1
        fi
        chmod 750 "$REPORT_DIR"
        chown root:adm "$REPORT_DIR" 2>/dev/null || chown root:root "$REPORT_DIR" 2>/dev/null
        log_message "Report directory $REPORT_DIR ensured."
    fi
}

check_log_readable() {
    if [ ! -r "$1" ]; then
        log_message "Error: Cannot read log file $1. Check permissions or if the file exists." >&2
        exit 1
    fi
    return 0
}

# --- Core Log Analysis Function ---

generate_failed_login_report_core() {
    log_message "Starting core failed login analysis for $TODAY."
    check_log_readable "$AUTH_LOG"

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

    if [ ! -s "$TEMP_FAILED_LOGINS_IP" ]; then
        echo "No failed login attempts recorded today for IP addresses (matching date pattern: $current_month_day_pattern or $current_month_day_pattern_alt)." >> "$REPORT_FILE"
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
    fi

    total_today_count=$(grep "Failed password" "$AUTH_LOG" | grep -E "($current_month_day_pattern|$current_month_day_pattern_alt)" | wc -l)
    echo "" >> "$REPORT_FILE"
    echo "Total failed login attempts (Today - matching date pattern: $current_month_day_pattern or $current_month_day_pattern_alt): $total_today_count" >> "$REPORT_FILE"

    log_message "Core failed login report section generated."
}

# --- Bonus Feature Functions ---

generate_weekly_summary() {
    if [ "$INCLUDE_WEEKLY" = "true" ]; then
        log_message "Generating weekly summary."
        echo "" >> "$REPORT_FILE"
        echo "Weekly Summary - Failed Login Attempts (Last 7 Days, excluding today):" >> "$REPORT_FILE"
        echo "---------------------------------------------------------------------" >> "$REPORT_FILE"
        
        local total_weekly_fails=0
        for i in $(seq 1 7); do
            day_to_check_date_format=$(date -d "$TODAY -$i days" +"%b %_d") # Format like "May  1"
            day_to_check_date_format_alt=$(date -d "$TODAY -$i days" +"%b %d") # Format like "May 01"
            day_display_format=$(date -d "$TODAY -$i days" +"%Y-%m-%d (%a)")
            
            # This grep is simplified; for accuracy across log rotations, more advanced parsing of auth.log, auth.log.1, auth.log.2.gz etc. is needed.
            # For this script, we search current AUTH_LOG and common rotated log names.
            daily_fail_count=$(grep "Failed password" "$AUTH_LOG"* "${AUTH_LOG%.*}.1" "${AUTH_LOG%.*}*.gz" 2>/dev/null | 
                               grep -E "($day_to_check_date_format|$day_to_check_date_format_alt)" | wc -l)
            echo "  $day_display_format: $daily_fail_count failed attempts" >> "$REPORT_FILE"
            total_weekly_fails=$((total_weekly_fails + daily_fail_count))
        done
        echo "Total failed attempts in the past 7 days (approximate, from available logs): $total_weekly_fails" >> "$REPORT_FILE"
        echo "Note: Weekly summary accuracy depends on availability and parsing of older/rotated log data." >> "$REPORT_FILE"
        log_message "Weekly summary appended to report."
    fi
}

handle_account_locking_check() {
    if [ "$LOCK_ACCOUNTS" = "true" ]; then
        log_message "Checking for accounts to lock based on $MAX_FAILS failed attempts (today)."
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
        else
            local user_locked_info_exists=false
            while IFS= read -r line; do
                count=$(echo "$line" | awk '{print $1}')
                user=$(echo "$line" | awk '{print $2}')
                
                if [ -z "$user" ]; then continue; fi

                if [ "$count" -ge "$MAX_FAILS" ]; then
                    log_message "ALERT: User '$user' has $count failed login attempts today, exceeding limit of $MAX_FAILS."
                    echo "  ALERT: User '$user' has $count failed login attempts today. Policy: Lock if >= $MAX_FAILS attempts."
                    echo "         Action: For production, configure pam_tally2 or fail2ban for actual locking." >> "$REPORT_FILE"
                    user_locked_info_exists=true
                fi
            done < "$TEMP_FAILED_LOGINS_USER"
            if [ "$user_locked_info_exists" = false ]; then
                 echo "No users met or exceeded the $MAX_FAILS failed attempts threshold today.">> "$REPORT_FILE"
            fi
        fi
        echo "Note: This script only reports potential accounts for locking. Actual locking requires tools like pam_tally2 or fail2ban." >> "$REPORT_FILE"
        log_message "Account locking check section appended to report."
    fi
}

send_report_by_email() {
    if [ "$SEND_EMAIL" = "true" ]; then
        if [ -z "$ADMIN_EMAIL_ADDR" ]; then
            log_message "Error: Admin email address (ADMIN_EMAIL) is not configured in config.sh. Cannot send email report." >&2
            echo "Error: Admin email address not set. Cannot send email." >> "$REPORT_FILE"
            return 1
        fi
        if ! command -v mail &> /dev/null && ! command -v mailx &> /dev/null ; then 
            log_message "Error: 'mail' command (from mailutils) not found. Cannot send email report." >&2
            echo "Error: 'mail' command not found. Please install mailutils." >> "$REPORT_FILE"
            return 1
        fi

        local subject="Security Report: Failed Logins - $TODAY"
        if [ ! -s "$REPORT_FILE" ]; then
            log_message "Report file $REPORT_FILE is empty or does not exist. Sending a 'no incidents' email instead."
            echo "Daily security report for $TODAY was generated but contained no relevant failed login entries." | mail -s "Security Report: No Failed Login Incidents - $TODAY" "$ADMIN_EMAIL_ADDR"
            if [ $? -eq 0 ]; then
                log_message "'No incidents' email successfully sent to $ADMIN_EMAIL_ADDR."
            else
                log_message "Error: Failed to send 'no incidents' email to $ADMIN_EMAIL_ADDR. Check mail system."
            fi
            return
        fi
        
        # Append a note about the email to the report itself for audit
        echo "" >> "$REPORT_FILE"
        echo "--- Email Notification --- " >> "$REPORT_FILE"
        echo "This report was scheduled to be emailed to: $ADMIN_EMAIL_ADDR" >> "$REPORT_FILE"

        cat "$REPORT_FILE" | mail -s "$subject" "$ADMIN_EMAIL_ADDR"
        if [ $? -eq 0 ]; then
            log_message "Security report successfully sent to $ADMIN_EMAIL_ADDR."
            echo "Email Status: Successfully sent." >> "$REPORT_FILE"
        else
            log_message "Error: Failed to send security report to $ADMIN_EMAIL_ADDR. Check mail system logs." >&2
            echo "Email Status: FAILED to send. Check system mail logs." >> "$REPORT_FILE"
        fi
    fi
}

# --- Main Execution (Core + Bonus) ---

main() {
    log_message "Log analysis script started (with bonus feature checks)."
    setup_report_dir

    generate_failed_login_report_core # This creates/overwrites $REPORT_FILE
    
    # Append bonus feature sections to the same report file
    generate_weekly_summary
    handle_account_locking_check
    
    # Send the consolidated report by email if enabled
    send_report_by_email    

    # Clean up temporary files
    rm -f "$TEMP_FAILED_LOGINS_IP" "$TEMP_FAILED_LOGINS_USER"

    chmod 640 "$REPORT_FILE" # Ensure final permissions
    log_message "Log analysis script finished. Report: $REPORT_FILE"
    exit 0
}

# Run main function
main

