#!/bin/bash

# Secure User & Log Management System Configuration File

# --- General Settings ---
# Base directory for the system (set during installation)
# SYS_BASE_DIR="/opt/secure-system"

# Log file for user management actions
USER_MGMT_LOG="/var/log/user_mgmt.log"

# Log file for authentication events (adjust for non-Debian systems, e.g., /var/log/secure for CentOS)
AUTH_LOG_FILE="/var/log/auth.log"

# Directory for security reports
SECURITY_REPORT_DIR="/var/log/security_reports"

# --- User Management Settings ---
# Minimum password length
PASSWORD_MIN_LENGTH=10

# Password complexity regex (requires lowercase, uppercase, number, special character)
# Ensure to escape special characters for use in bash scripts if needed directly.
PASSWORD_COMPLEXITY_REGEX="^(?=.*[a-z])(?=.*[A-Z])(?=.*[0-9])(?=.*[!@#$%^&*])"

# --- Bonus Feature Toggles (can be enabled during installation) ---
# Send daily security reports via email (true/false)
SEND_EMAIL_REPORTS="false"
# Email address for sending reports (will be prompted during installation if SEND_EMAIL_REPORTS is true)
ADMIN_EMAIL=""

# Include a weekly summary of failed login attempts in daily reports (true/false)
INCLUDE_WEEKLY_SUMMARY="false"

# Automatically lock user accounts after a specified number of failed login attempts (true/false)
ENABLE_ACCOUNT_LOCKING="false"
# Number of failed attempts before locking an account (if ENABLE_ACCOUNT_LOCKING is true)
MAX_FAILED_ATTEMPTS=5
# Duration to lock account in minutes (if ENABLE_ACCOUNT_LOCKING is true, e.g., 30 for 30 minutes)
# Use with pam_tally2 or fail2ban. This config is a placeholder for script logic.
ACCOUNT_LOCK_DURATION=30

# --- FTP Server Settings (vsftpd) ---
# Path to SSL certificate for vsftpd
VSFTPD_CERT_FILE="/etc/ssl/private/vsftpd.pem"
# Path to SSL private key for vsftpd
VSFTPD_KEY_FILE="/etc/ssl/private/vsftpd.pem"

# --- Logrotate Settings ---
# How often to rotate user_mgmt.log (e.g., weekly, daily)
LOGROTATE_USER_MGMT_FREQUENCY="weekly"
# How many rotated user_mgmt.log files to keep
LOGROTATE_USER_MGMT_KEEP=4

# How often to rotate security_reports (e.g., daily, weekly)
LOGROTATE_SECURITY_REPORTS_FREQUENCY="daily"
# How many rotated security_reports to keep (e.g., 30 for daily reports for a month)
LOGROTATE_SECURITY_REPORTS_KEEP=30

# End of configuration file

