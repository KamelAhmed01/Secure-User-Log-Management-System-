# SecLogs: Enhanced Secure User & Log Management System

## Overview

SecLogs is a comprehensive command-line tool designed to enhance security and streamline administration on Linux systems. It combines robust secure log analysis with automated user management, now featuring an improved user experience with a more intuitive interface, ASCII art branding, loading animations, and simplified command access.

Key functionalities include setting up a secure FTP server (vsftpd), analyzing authentication logs (e.g., `/var/log/auth.log`) for suspicious activities like failed login attempts, generating daily security reports, automating user lifecycle management with strong password policies, and maintaining detailed logs of all administrative actions.

## Features

### Core System Features:

-   **Secure FTP Server (vsftpd)**: Automates the setup of vsftpd with TLS/SSL encryption for secure file transfers. The installation process prompts for necessary SSL certificate details.
-   **Log Analysis (`log_analysis.sh`)**:
    -   Scans the system authentication log for "Failed password" entries.
    -   Aggregates login failures per IP address for the current day.
    -   Generates daily reports summarizing failed login attempts, stored by default in `/var/log/security_reports/`.
-   **User Management (`user_management.sh`)**:
    -   Provides automated functions for user creation (`useradd`), deletion (`userdel`), and modification (`usermod`).
    -   Enforces strong password policies, configurable for length and complexity.
    -   Mandates a password change upon first login for newly created users.
-   **Action Logging**: All user management actions performed through SecLogs are meticulously logged to `/var/log/user_mgmt.log` (default), including timestamps and the administrator responsible.
-   **Log Rotation**: Configures `logrotate` for both the user management log and the security reports to ensure efficient disk space management.

### User Experience Enhancements:

-   **Enhanced Menu-Driven Interface (`secure_system.sh`)**: The central script now features a more professional and user-friendly interface with:
    -   **Color-coded menus** for better readability and visual appeal.
    -   **ASCII art branding** (`SecLogs`) displayed at startup.
    -   **Loading animations** for operations that may take time (e.g., report generation, service restarts), providing visual feedback to the user.
-   **Simplified Command Execution**: After installation, the tool can be easily invoked using the `seclogs` command (e.g., `sudo seclogs`), thanks to a system-wide symlink.

### Bonus Features (Configurable During Installation):

-   **Email Daily Security Reports**: If enabled, daily failed login reports are automatically emailed to a specified administrator address.
-   **Weekly Summary in Reports**: If enabled, the daily report includes a summary of failed login attempts over the past 7 days.
-   **Conceptual Account Locking Check**: If enabled, the daily report flags users who have exceeded a configurable number of failed login attempts on that day. (Note: This is a reporting feature; actual account locking requires system-level tools like `pam_tally2` or `fail2ban`.)

## System Requirements

-   A Linux distribution (Debian/Ubuntu-based is recommended for `apt` package management and default log paths).
-   Root or sudo privileges for installation and execution of most functions.
-   Essential command-line utilities: `bash`, `grep`, `awk`, `sed`, `sort`, `uniq`, `date`, `useradd`, `usermod`, `userdel`, `chpasswd`, `passwd`.
-   `vsftpd` for the Secure FTP server feature.
-   `openssl` for generating SSL certificates.
-   `cron` (or a compatible cron daemon) for scheduled daily log analysis.
-   `mailutils` (provides the `mail` command) if the email reporting feature is enabled.

## Installation

1.  **Download and Extract**:
    Obtain the SecLogs project archive (e.g., `seclogs_project.zip`) and extract it to a temporary location on your server.

    ```bash
    unzip seclogs_project.zip -d seclogs_project
    cd seclogs_project
    ```

2.  **Run the Installer**:
    Execute the installation script (`install.sh`) with root privileges. The installer will guide you through the process, check for dependencies, and prompt for configuration choices.

    ```bash
    sudo ./install.sh
    ```

    The installer will perform the following actions:

    -   Check for and offer to install missing dependencies (vsftpd, openssl, cron, mailutils).
    -   Create necessary directories (default: `/opt/secure-system`).
    -   Copy system scripts (including `secure_system.sh`, `user_management.sh`, `log_analysis.sh`, `loading_animation.sh`) to `/opt/secure-system/scripts/` and set appropriate permissions.
    -   Copy the `ascii_art.txt` file to `/opt/secure-system/`.
    -   Copy logrotate configuration templates to `/opt/secure-system/config/`.
    -   Create a symbolic link at `/usr/local/bin/seclogs` pointing to the main script, allowing you to run the tool with `sudo seclogs`.
    -   Prompt for SSL certificate details if vsftpd setup is confirmed (Country, State, City, Organization, Common Name).
    -   Configure vsftpd with SSL/TLS.
    -   Set up logrotate for system logs (`user_mgmt.log` and security reports).
    -   Attempt to configure a cron job for daily execution of `log_analysis.sh`.
    -   Prompt you to enable/disable bonus features and configure related settings (e.g., administrator email for reports).

3.  **Post-Installation Verification**:
    -   Carefully review the output of the installer for any errors or warnings.
    -   Verify that the `seclogs` command is available and works:
        ```bash
        which seclogs
        # Expected output: /usr/local/bin/seclogs
        sudo seclogs
        # The main menu with ASCII art should appear.
        ```
    -   **Cron Job Verification**: The installer attempts to add a cron job. Verify its presence:
        ```bash
        sudo crontab -l
        ```
        You should see an entry similar to: `0 0 * * * /opt/secure-system/scripts/log_analysis.sh`. If it is missing or you prefer manual setup, add it by editing the root crontab (`sudo crontab -e`).
    -   **FTP Server (if configured)**:
        -   Check vsftpd status: `sudo systemctl status vsftpd`.
        -   If you use a firewall (e.g., `ufw`), ensure ports 20, 21, and any configured passive ports (e.g., 40000-50000 if enabled in `/etc/vsftpd.conf`) are open for TCP traffic.

## Configuration

The main configuration file for the system is located at `/opt/secure-system/scripts/config.sh` (assuming the default installation path). This file is populated during installation based on your choices but can be manually edited later if needed. Remember that `sudo` is required to edit this file.

Key configurable parameters include:

-   `USER_MGMT_LOG`: Path to the user management log file.
-   `AUTH_LOG_FILE`: Path to the system authentication log.
-   `SECURITY_REPORT_DIR`: Directory for storing daily security reports.
-   `PASSWORD_MIN_LENGTH`: Minimum password length for new users.
-   `PASSWORD_COMPLEXITY_REGEX`: Regular expression for password complexity enforcement.
-   `SEND_EMAIL_REPORTS`: (`true`/`false`) Toggle for emailing daily reports.
-   `ADMIN_EMAIL`: Email address for receiving reports.
-   `INCLUDE_WEEKLY_SUMMARY`: (`true`/`false`) Toggle for including a 7-day summary in reports.
-   `ENABLE_ACCOUNT_LOCKING`: (`true`/`false`) Toggle for the conceptual account locking check feature.
-   `MAX_FAILED_ATTEMPTS`: Threshold for flagging accounts in the locking check.
-   `VSFTPD_CERT_FILE` / `VSFTPD_KEY_FILE`: Paths to vsftpd SSL certificate and key.
-   Logrotate frequencies and retention periods.

**Important**: After modifying `config.sh`, no service restarts are typically needed for the SecLogs scripts themselves. However, if you change vsftpd related paths that were used during its setup, vsftpd might need a restart.

## Usage

Access all SecLogs functionalities through the main interface script. After successful installation, run it with `sudo` using the simplified command:

```bash
sudo seclogs
```

This will launch the enhanced menu-driven interface, displaying the SecLogs ASCII art logo and color-coded options:

1.  **User Management**: Access sub-menu for user operations.
    -   Create New User: Prompts for username and password (enforces policy).
    -   Delete Existing User: Prompts for username and option to remove home directory.
    -   Modify Existing User: Options to change password, shell, set expiry, lock/unlock account.
    -   List Users: Displays non-system users.
2.  **Log Analysis & Reporting**: Access sub-menu for log operations.
    -   Generate Daily Failed Login Report (Now): Manually triggers `log_analysis.sh`. A loading animation will be displayed during generation.
    -   View Latest Failed Login Report: Displays the most recent report from the security reports directory.
3.  **Secure FTP Server Status**: Checks and displays the current status of the `vsftpd` service. Offers to start the service (with a loading animation) if it is not running.
4.  **View System Configuration**: Displays the content of the `config.sh` file.
5.  **Exit**: Exits the SecLogs management interface.

### Daily Operations (Automated via Cron)

If the cron job is correctly configured during installation, the `log_analysis.sh` script will run automatically every day (typically at midnight). This script will:

-   Analyze the authentication log for failed login attempts from the current day.
-   Generate a report in the security reports directory.
-   If enabled, include a weekly summary of failed attempts.
-   If enabled, include information about accounts potentially needing a lock (conceptual feature).
-   If enabled, email the report to the configured administrator.

## Log Files

-   **User Management Log**: `/var/log/user_mgmt.log` (or as configured in `config.sh`) - Records all actions performed via the user management interface.
-   **Security Reports**: `/var/log/security_reports/` (or as configured) - Contains daily failed login attempt reports (e.g., `failed_logins_report_YYYY-MM-DD.txt`).
-   **System Authentication Log**: Typically `/var/log/auth.log` (standard system log, analyzed by SecLogs).
-   **vsftpd Log**: Typically `/var/log/vsftpd.log` (as configured in `vsftpd.conf`).

## Uninstallation

A dedicated uninstallation script (`uninstall.sh`) is provided to remove SecLogs from your system. This script must also be run with root privileges.

1.  **Navigate to the directory** where you extracted the SecLogs project files (the one containing `uninstall.sh`).
2.  **Run the Uninstaller**:
    ```bash
    sudo ./uninstall.sh
    ```
    The uninstaller will:
    -   Prompt for confirmation before proceeding.
    -   Remove the `seclogs` symlink from `/usr/local/bin/`.
    -   Remove the cron job for `log_analysis.sh`.
    -   Remove the SecLogs logrotate configurations from `/etc/logrotate.d/`.
    -   Remove the main system files directory (default: `/opt/secure-system`).
    -   Optionally, prompt you to remove user management logs and security reports. You will be asked separately for each.
    -   Provide information regarding manual cleanup of vsftpd if it was installed or configured by SecLogs.

**Important**: The uninstaller does **not** automatically uninstall `vsftpd`, `openssl`, `cron`, or `mailutils` if they were installed as dependencies. This is to avoid removing packages that might be used by other system services. You can remove these manually using your system's package manager (e.g., `sudo apt purge vsftpd`) if they are no longer needed.

## Troubleshooting

-   **`seclogs: command not found`**: This usually means the symlink at `/usr/local/bin/seclogs` was not created correctly during installation, or `/usr/local/bin` is not in your system's `PATH` for the root user. Verify the symlink exists. If not, you can try re-running the `install.sh` script or manually creating the symlink: `sudo ln -s /opt/secure-system/scripts/secure_system.sh /usr/local/bin/seclogs`.
-   **Script Permission Errors**: Ensure all scripts in `/opt/secure-system/scripts/` are executable (`chmod +x script_name.sh`). The installer should handle this, but it is worth checking if issues arise.
-   **Dependency "Command not found" errors within scripts**: Ensure all dependencies listed in "System Requirements" are installed.
-   **vsftpd Fails to Start**: Check `sudo journalctl -u vsftpd` or `/var/log/vsftpd.log` for errors. Common issues include SSL certificate problems or incorrect `vsftpd.conf` settings.
-   **Cron Job Not Running**:
    -   Verify the cron daemon is running: `sudo systemctl status cron`.
    -   Check cron logs (often in `/var/log/syslog` or `/var/log/cron.log`) for errors related to the job.
    -   Ensure the script path in the crontab is correct and the script is executable by root.
-   **Email Reports Not Sent**:
    -   Verify `mailutils` is installed and the `mail` command works from the command line.
    -   Check your system's mail server configuration (e.g., Postfix, Sendmail). The `mail` command often relies on a local Mail Transfer Agent (MTA).
    -   Check mail logs (e.g., `/var/log/mail.log`) for errors.
    -   Ensure `ADMIN_EMAIL` in `config.sh` is correct and `SEND_EMAIL_REPORTS` is set to `true`.

## Demonstration Scenario

For a guided walkthrough of the installation, features, and uninstallation process, please refer to the `demo_scenario.md` file included with this project.

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.

