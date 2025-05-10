# Secure User & Log Management System

## Overview

This system provides a dual-function tool combining secure log analysis with automated user management for Linux systems. It is designed to enhance security by monitoring authentication logs for suspicious activity and to streamline user administration tasks. Key features include a secure FTP server, analysis of `/var/log/auth.log` for failed login attempts, daily security reporting, automated user lifecycle management with strong password enforcement, and comprehensive logging of all administrative actions.

## Features

### Core Features:

- **Secure FTP Server (vsftpd)**: Sets up vsftpd with TLS/SSL encryption for secure file transfers. The installation prompts for SSL certificate details.
- **Log Analysis (`log_analysis.sh`)**:
  - Scans `/var/log/auth.log` (or equivalent) for "Failed password" entries.
  - Counts login failures per IP address for the current day.
  - Generates daily reports summarizing failed login attempts, stored in `/var/log/security_reports/`.
- **User Management (`user_management.sh`)**:
  - Automates user creation (`useradd`), deletion (`userdel`), and modification (`usermod`).
  - Enforces strong password policies (configurable length and complexity).
  - Requires password change on first login for new users.
- **Action Logging**: All user management actions performed via the system are logged to `/var/log/user_mgmt.log` with timestamps and the responsible administrator.
- **Menu-Driven Interface (`secure_system.sh`)**: A centralized Bash script providing easy access to all system functionalities.
- **Log Rotation**: Configures `logrotate` for both `user_mgmt.log` and the security reports in `/var/log/security_reports/` to manage disk space.

### Bonus Features (Configurable during Installation):

- **Email Daily Security Reports**: If enabled, the daily failed login report is automatically emailed to a specified administrator address.
- **Weekly Summary in Reports**: If enabled, the daily report includes a summary of failed login attempts over the past 7 days.
- **Conceptual Account Locking Check**: If enabled, the daily report will flag users who have exceeded a configurable number of failed login attempts on that day. This is a reporting feature; actual account locking requires system-level tools like `pam_tally2` or `fail2ban`.

## System Requirements

- A Linux distribution (Debian/Ubuntu-based recommended for `apt` and default log paths).
- Root or sudo privileges for installation and execution of most functions.
- Essential command-line utilities: `bash`, `grep`, `awk`, `sed`, `sort`, `uniq`, `date`, `useradd`, `usermod`, `userdel`, `chpasswd`, `passwd`.
- `vsftpd` for the Secure FTP server.
- `openssl` for generating SSL certificates.
- `cron` (or a compatible cron daemon) for scheduled daily log analysis.
- `mailutils` (provides the `mail` command) if email reporting is enabled.

## Installation

1.  **Download and Extract**:
    Obtain the `secure-system.zip` file and extract it to a temporary location on your server.

    ```bash
    unzip secure-system.zip
    cd secure-system
    ```

2.  **Run the Installer**:
    Execute the installation script with root privileges. The installer will guide you through the process, check for dependencies, and prompt for configuration choices.

    ```bash
    sudo ./install.sh
    ```

    The installer will:

    - Check for and offer to install missing dependencies (vsftpd, openssl, cron, mailutils).
    - Create necessary directories (default: `/opt/secure-system`).
    - Copy system scripts to `/opt/secure-system/scripts/` and set permissions.
    - Copy logrotate configuration templates.
    - Prompt for SSL certificate details for vsftpd (Country, State, City, Organization, Common Name).
    - Configure vsftpd with SSL/TLS.
    - Set up logrotate for system logs.
    - Attempt to configure a cron job for daily execution of `log_analysis.sh`.
    - Prompt you to enable/disable bonus features and configure related settings (e.g., admin email).

3.  **Post-Installation Verification**:
    - Check the output of the installer for any errors or warnings.
    - Verify that the main script is executable: `sudo /opt/secure-system/scripts/secure_system.sh`.
    - **Cron Job Verification**:
      - The installer attempts to add a cron job. Verify its presence:
        ```bash
        sudo crontab -l
        ```
      - You should see an entry similar to: `0 0 * * * /opt/secure-system/scripts/log_analysis.sh`.
      - If it's missing or you prefer manual setup, add it by editing the root crontab (`sudo crontab -e`) and adding the line above.
    - **FTP Server**:
      - Check vsftpd status: `sudo systemctl status vsftpd`.
      - If you use a firewall (e.g., `ufw`), ensure ports 20, 21, and any configured passive ports (e.g., 40000-50000 if enabled in `/etc/vsftpd.conf`) are open for TCP traffic.
        Example for `ufw`:
      ```bash
      sudo ufw allow 20/tcp
      sudo ufw allow 21/tcp
      # sudo ufw allow 40000:50000/tcp # If passive mode is enabled
      sudo ufw reload
      ```

## Configuration

The main configuration file for the system is located at `/opt/secure-system/scripts/config.sh` (assuming default installation path). This file is populated during installation but can be manually edited later if needed.

Key configurable parameters include:

- `USER_MGMT_LOG`: Path to the user management log file (default: `/var/log/user_mgmt.log`).
- `AUTH_LOG_FILE`: Path to the system authentication log (default: `/var/log/auth.log`).
- `SECURITY_REPORT_DIR`: Directory for storing daily security reports (default: `/var/log/security_reports`).
- `PASSWORD_MIN_LENGTH`: Minimum password length for new users.
- `PASSWORD_COMPLEXITY_REGEX`: Regex for password complexity enforcement.
- `SEND_EMAIL_REPORTS`: (`true`/`false`) Toggle for emailing daily reports.
- `ADMIN_EMAIL`: Email address for receiving reports.
- `INCLUDE_WEEKLY_SUMMARY`: (`true`/`false`) Toggle for including a 7-day summary in reports.
- `ENABLE_ACCOUNT_LOCKING`: (`true`/`false`) Toggle for the conceptual account locking check feature.
- `MAX_FAILED_ATTEMPTS`: Threshold for flagging accounts in the locking check.
- `VSFTPD_CERT_FILE` / `VSFTPD_KEY_FILE`: Paths to vsftpd SSL certificate and key.
- Logrotate frequencies and retention periods.

**Important**: After modifying `config.sh`, no service restarts are typically needed unless you change paths that affect running daemons (which is unlikely for this script-based system, apart from initial FTP setup).

## Usage

All system functionalities are accessed through the main interface script. Run it with sudo:

```bash
sudo /opt/secure-system/scripts/secure_system.sh
```

This will present a menu with the following options:

1.  **User Management**:

    - Create New User: Prompts for username and password (enforces policy).
    - Delete Existing User: Prompts for username and option to remove home directory.
    - Modify Existing User: Options to change password, shell, set expiry, lock/unlock account.
    - List Users: Displays non-system users.

2.  **Log Analysis & Reporting**:

    - Generate Daily Failed Login Report (Now): Manually triggers the `log_analysis.sh` script.
    - View Latest Failed Login Report: Displays the most recent report from `/var/log/security_reports/`.

3.  **Secure FTP Server Status**:

    - Checks and displays the current status of the `vsftpd` service.
    - Offers to start the service if it's not running.

4.  **View System Configuration**:

    - Displays the content of the `config.sh` file.

5.  **Exit**:
    - Exits the management interface.

### Daily Operations (Automated via Cron)

If the cron job is correctly configured, the `log_analysis.sh` script will run automatically every day at midnight. This script will:

- Analyze `/var/log/auth.log` for failed login attempts from the current day.
- Generate a report in `/var/log/security_reports/`.
- If enabled, include a weekly summary of failed attempts.
- If enabled, include information about accounts potentially needing a lock.
- If enabled, email the report to the configured administrator.

## Log Files

- **User Management Log**: `/var/log/user_mgmt.log` (or as configured) - Records all actions performed via the user management interface.
- **Security Reports**: `/var/log/security_reports/` (or as configured) - Contains daily failed login attempt reports (e.g., `failed_logins_report_YYYY-MM-DD.txt`).
- **System Authentication Log**: `/var/log/auth.log` (standard system log, analyzed by this tool).
- **vsftpd Log**: Typically `/var/log/vsftpd.log` (configured in `vsftpd.conf`).

## Uninstallation

While an automated uninstaller is not provided, you can remove the system by following these steps:

1.  **Remove Cron Job**:

    ```bash
    sudo crontab -e
    ```

    Delete the line corresponding to `/opt/secure-system/scripts/log_analysis.sh`.

2.  **Remove Logrotate Configurations**:

    ```bash
    sudo rm /etc/logrotate.d/secure_system_user_mgmt
    sudo rm /etc/logrotate.d/secure_system_security_reports
    ```

3.  **Remove System Files**:

    ```bash
    sudo rm -rf /opt/secure-system
    ```

4.  **Remove Log Files and Reports (Optional)**:

    ```bash
    sudo rm /var/log/user_mgmt.log
    sudo rm -rf /var/log/security_reports
    ```

5.  **vsftpd Configuration (Optional)**:
    - If you wish to revert vsftpd configuration, the installer creates a backup (e.g., `/etc/vsftpd.conf.bak_YYYY-MM-DD-HH:MM:SS`). You can restore it.
    - If you wish to remove vsftpd entirely: `sudo apt purge vsftpd` (or equivalent for your distribution).
    - Remove the SSL certificate: `sudo rm /etc/ssl/private/vsftpd.pem` (or configured path).

## Troubleshooting

- **Script Permission Errors**: Ensure all scripts in `/opt/secure-system/scripts/` are executable (`chmod +x script_name.sh`). The installer should handle this.
- **"Command not found"**: Ensure all dependencies listed in "System Requirements" are installed.
- **vsftpd Fails to Start**: Check `sudo journalctl -u vsftpd` or `/var/log/vsftpd.log` for errors. Common issues include SSL certificate problems or incorrect `vsftpd.conf` settings.
- **Cron Job Not Running**:
  - Verify cron daemon is running: `sudo systemctl status cron`.
  - Check cron logs (often in `/var/log/syslog` or `/var/log/cron.log`) for errors related to the job.
  - Ensure the script path in the crontab is correct and the script is executable by root.
- **Email Reports Not Sent**:
  - Verify `mailutils` is installed and the `mail` command works.
  - Check your system's mail server configuration (e.g., Postfix, Sendmail). The `mail` command often relies on a local MTA.
  - Check mail logs (e.g., `/var/log/mail.log`) for errors.
  - Ensure `ADMIN_EMAIL` in `config.sh` is correct.

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.
