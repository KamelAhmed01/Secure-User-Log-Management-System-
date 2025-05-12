# SecLogs Project: Demonstration Scenario & Practice Script

This document outlines a scenario to demonstrate the features and enhancements of the SecLogs project. It is designed for a live presentation or practice session.

## 1. Prerequisites

*   A Linux environment (preferably Debian/Ubuntu-based for full compatibility with `apt` and default paths).
*   Root or sudo privileges.
*   The enhanced SecLogs project files (e.g., `seclogs_enhanced.zip` containing the `install.sh`, `uninstall.sh`, `scripts/`, `config/`, `ascii_art.txt`, and `README.md`).
*   Ensure no previous versions of SecLogs are installed or conflicting tools are running on common ports if FTP is to be tested.

## 2. Preparation

1.  Transfer the project archive (e.g., `seclogs_enhanced.zip`) to the demonstration machine.
2.  Open a terminal.
3.  Extract the project: `unzip seclogs_enhanced.zip -d seclogs_project_demo`
4.  Navigate into the project directory: `cd seclogs_project_demo`

## 3. Demonstration Steps

### Step 3.1: Installation

*   **Objective**: Showcase the new installation process and the creation of the `seclogs` command.
*   **Action**:
    *   Explain that you are about to run the installer.
    *   Execute the installer: `sudo ./install.sh`
    *   During installation:
        *   Point out the dependency checks.
        *   When prompted for vsftpd, openssl, cron, mailutils, answer according to your demo setup (e.g., 'y' to install if not present, or acknowledge if already there).
        *   For SSL certificate details, you can use default values or provide sample information.
        *   For bonus features (email reports, weekly summary, account locking check), demonstrate enabling one or two features and configuring them (e.g., provide a dummy admin email).
        *   Highlight the creation of the `seclogs` symlink at the end of the installation log.
*   **Verification**: After installation, confirm that the `seclogs` command is available by typing `which seclogs` (should point to `/usr/local/bin/seclogs`).

### Step 3.2: First Run & UI Showcase

*   **Objective**: Demonstrate the enhanced UI, ASCII art, and basic navigation.
*   **Action**:
    *   Run the tool: `sudo seclogs`
    *   **Showcase**: 
        *   The ASCII art logo displayed at startup.
        *   The colored and formatted main menu.
        *   Explain the available options.

### Step 3.3: User Management Demonstration

*   **Objective**: Demonstrate core user management functionalities.
*   **Action**:
    1.  From the main menu, select **User Management**.
    2.  **Create New User**:
        *   Select option 1.
        *   Enter a sample username (e.g., `demouser1`).
        *   Enter a password that meets the policy (explain the policy if prompted or if it fails).
        *   Point out any loading animations if they appear during this process.
    3.  **List Users**:
        *   Select option 4.
        *   Show that `demouser1` is now listed.
    4.  **(Optional) Modify User**: Briefly show the modify options.
    5.  **Delete Existing User**:
        *   Select option 2.
        *   Enter `demouser1` to delete.
        *   Confirm deletion (and home directory removal if prompted).
    6.  **List Users** again to show `demouser1` is gone.
    7.  Return to the main menu.

### Step 3.4: Log Analysis & Reporting Demonstration

*   **Objective**: Demonstrate log analysis and report viewing.
*   **Action**:
    1.  From the main menu, select **Log Analysis & Reporting**.
    2.  **Generate Daily Failed Login Report (Now)**:
        *   Select option 1.
        *   **Showcase**: The loading animation while the report is generated.
        *   Acknowledge the confirmation message.
    3.  **View Latest Failed Login Report**:
        *   Select option 2.
        *   Display the content of the report. If this is a fresh system, there might be no failed logins. *Consider manually creating some failed login attempts beforehand if you want to show data in the report (e.g., try to SSH with a wrong password).* 
    4.  Return to the main menu.

### Step 3.5: Secure FTP Server Status

*   **Objective**: Demonstrate checking FTP server status.
*   **Action**:
    1.  From the main menu, select **Secure FTP Server Status**.
    2.  Observe the output. If vsftpd was installed and configured, it should show as active.
    3.  If it's not active, demonstrate the option to start it (and the loading animation).
    4.  Return to the main menu.

### Step 3.6: View System Configuration

*   **Objective**: Show how to view the current configuration.
*   **Action**:
    1.  From the main menu, select **View System Configuration**.
    2.  Briefly scroll through the displayed `config.sh` content, pointing out any settings that were configured during installation (e.g., admin email if bonus feature was enabled).
    3.  Return to the main menu.

### Step 3.7: Exiting the Tool

*   **Objective**: Show how to exit the tool.
*   **Action**: Select option 0 (Exit) from the main menu.

### Step 3.8: Uninstallation

*   **Objective**: Demonstrate the new uninstallation process.
*   **Action**:
    *   Navigate back to the directory where `uninstall.sh` is located (e.g., `cd seclogs_project_demo`).
    *   Execute the uninstaller: `sudo ./uninstall.sh`
    *   When prompted for confirmation, answer 'y'.
    *   Point out the steps being performed by the uninstaller (removing symlink, cron job, logrotate configs, system files).
    *   When prompted to remove logs and reports, demonstrate answering 'y' for one and 'n' for another, or 'y' for both.
    *   Acknowledge the vsftpd cleanup information.
*   **Verification**: 
    *   Try running `sudo seclogs` again – it should fail (command not found).
    *   Check if `/opt/secure-system` directory is gone: `ls /opt/secure-system` (should report 'No such file or directory').
    *   Check if `/usr/local/bin/seclogs` is gone: `ls /usr/local/bin/seclogs`.

## 4. Presentation Tips

*   **Narrate your actions**: Clearly explain what you are doing and why, especially highlighting the new features and improvements.
*   **Emphasize UI/UX changes**: Point out the ASCII art, colors, loading spinners, and the simplified `seclogs` command.
*   **Explain the benefits**: Connect features to user benefits (e.g., "The `seclogs` command makes it much easier to run the tool without remembering the full path.", "The loading animation provides feedback during longer operations.").
*   **Be prepared for questions**: Anticipate questions about specific features, security implications, or customization.
*   **Have a backup plan**: If a live demo encounters issues, be ready to talk through the steps or show screenshots/recordings.
*   **Keep it concise**: Focus on the key enhancements and the overall workflow.

This scenario provides a comprehensive walkthrough of the SecLogs project. Adapt it as needed for your specific audience and time constraints.
