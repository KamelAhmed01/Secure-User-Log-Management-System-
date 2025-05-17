#!/bin/bash

# Script for User Account Management (Core Functionality)
# Automates user creation, deletion, and modification with password policies and logging.

# Source configuration
CONFIG_FILE="$(dirname "$(readlink -f "$0")")/config.sh"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "Error: Configuration file $CONFIG_FILE not found." >&2
    # Attempt to source from a default location if this script is called directly for testing
    if [ -f "./config.sh" ]; then source "./config.sh"; 
    elif [ -f "../scripts/config.sh" ]; then source "../scripts/config.sh"; 
    else echo "Error: Fallback configuration file not found." >&2; exit 1; fi
fi

# Variables from config (or defaults if not set)
LOG_FILE="${USER_MGMT_LOG:-/var/log/user_mgmt.log}"
PASSWORD_MIN_LEN="${PASSWORD_MIN_LENGTH:-10}"
PASSWORD_REGEX="${PASSWORD_COMPLEXITY_REGEX:-^(?=.*[a-z])(?=.*[A-Z])(?=.*[0-9])(?=.*[!@#$%^&*])}"

# --- Helper Functions ---

# Logging function
log_action() {
    if [ ! -f "$LOG_FILE" ]; then
        sudo touch "$LOG_FILE"
        sudo chmod 640 "$LOG_FILE"
        # Attempt to set group ownership to adm, common for logs. Fallback if it fails.
        sudo chown root:adm "$LOG_FILE" 2>/dev/null || sudo chown root:root "$LOG_FILE" 2>/dev/null
        if [ $? -ne 0 ]; then echo "Warning: Could not set ownership for $LOG_FILE" >&2; fi
    fi
    local effective_user="${SUDO_USER:-$(whoami)}"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - User: $effective_user - Action: $1" | sudo tee -a "$LOG_FILE" > /dev/null
}

# Password validation function
validate_password() {
    local password="$1"
    local username="$2" 

    if [ ${#password} -lt "$PASSWORD_MIN_LEN" ]; then
        echo "Error: Password must be at least $PASSWORD_MIN_LEN characters long."
        return 1
    fi

    if ! echo "$password" | grep -qP "$PASSWORD_REGEX"; then
        echo "Error: Password does not meet complexity requirements."
        echo "Requirement: Must include lowercase, uppercase, number, and a special character (e.g., !@#$%^&*)."
        return 1
    fi

    if [ -n "$username" ]; then
        if echo "$password" | grep -iq "$username"; then 
            echo "Error: Password cannot contain the username."
            return 1
        fi
    fi
    return 0
}

# --- User Management Functions (Core) ---

create_new_user() {
    local username
    local password

    read -r -p "Enter username to create: " username
    if [ -z "$username" ]; then
        echo "Error: Username cannot be empty."
        log_action "CREATE_USER_FAILED: Empty username provided."
        return 1
    fi

    if id "$username" &>/dev/null; then
        echo "Error: User 	'$username	' already exists."
        log_action "CREATE_USER_FAILED: User 	'$username	' already exists."
        return 1
    fi

    while true; do
        read -s -r -p "Enter password for $username: " password
        echo
        read -s -r -p "Confirm password: " password_confirm
        echo

        if [ "$password" != "$password_confirm" ]; then
            echo "Error: Passwords do not match. Please try again."
            continue
        fi

        if validate_password "$password" "$username"; then
            break
        else
            read -r -p "Do you want to try a different password? (y/n): " choice
            if [[ "$choice" != "y" && "$choice" != "Y" ]]; then
                log_action "CREATE_USER_FAILED: Password validation failed for 	'$username	', user aborted."
                return 1
            fi 
        fi
    done

    sudo useradd -m -s /bin/bash "$username"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create user 	'$username	'. Check system logs."
        log_action "CREATE_USER_FAILED: useradd command failed for 	'$username	'."
        return 1
    fi

    echo "$username:$password" | sudo chpasswd
    if [ $? -ne 0 ]; then
        echo "Error: Failed to set password for user 	'$username	'."
        sudo userdel -r "$username" 2>/dev/null 
        log_action "CREATE_USER_FAILED: chpasswd command failed for 	'$username	'. User removed."
        return 1
    fi

    sudo passwd -e "$username" >/dev/null
    echo "User 	'$username	' created successfully. Password must be changed on first login."
    log_action "CREATE_USER_SUCCESS: User 	'$username	' created."
    return 0
}

delete_existing_user() {
    local username
    local remove_home_dir_choice

    read -r -p "Enter username to delete: " username
    if [ -z "$username" ]; then
        echo "Error: Username cannot be empty."
        log_action "DELETE_USER_FAILED: Empty username provided."
        return 1
    fi

    if ! id "$username" &>/dev/null; then
        echo "Error: User 	'$username	' does not exist."
        log_action "DELETE_USER_FAILED: User 	'$username	' does not exist."
        return 1
    fi

    if [ "$username" == "root" ] || [ "$username" == "$(whoami)" ] || [ "$username" == "${SUDO_USER:-$(whoami)}" ]; then
        echo "Error: Deleting user 	'$username	' is not allowed."
        log_action "DELETE_USER_FAILED: Attempt to delete critical user 	'$username	'."
        return 1
    fi

    read -r -p "Do you want to remove the home directory for 	'$username	'? (yes/no) [no]: " remove_home_dir_choice

    if [[ "$remove_home_dir_choice" == "yes" || "$remove_home_dir_choice" == "YES" ]]; then
        sudo userdel -r "$username"
        if [ $? -eq 0 ]; then
            echo "User 	'$username	' and their home directory have been deleted."
            log_action "DELETE_USER_SUCCESS: User 	'$username	' deleted with home directory."
        else
            echo "Error: Failed to delete user 	'$username	' with home directory. Check system logs."
            log_action "DELETE_USER_FAILED: userdel -r command failed for 	'$username	'."
            return 1
        fi
    else
        sudo userdel "$username"
        if [ $? -eq 0 ]; then
            echo "User 	'$username	' has been deleted. Home directory preserved."
            log_action "DELETE_USER_SUCCESS: User 	'$username	' deleted. Home directory preserved."
        else
            echo "Error: Failed to delete user 	'$username	'. Check system logs."
            log_action "DELETE_USER_FAILED: userdel command failed for 	'$username	'."
            return 1
        fi
    fi
    return 0
}

modify_existing_user() {
    local username
    local option

    read -r -p "Enter username to modify: " username
    if [ -z "$username" ]; then
        echo "Error: Username cannot be empty."
        log_action "MODIFY_USER_FAILED: Empty username for modification."
        return 1
    fi

    if ! id "$username" &>/dev/null; then
        echo "Error: User 	'$username	' does not exist."
        log_action "MODIFY_USER_FAILED: User 	'$username	' for modification does not exist."
        return 1
    fi

    echo "User Modification Options for 	'$username	':"
    echo "  1. Change Password"
    echo "  2. Change Login Shell"
    echo "  3. Set Account Expiry Date"
    echo "  4. Lock Account"
    echo "  5. Unlock Account"
    read -r -p "Select an option (1-5): " option

    case "$option" in
        1) # Change Password
            local new_password
            while true; do
                read -s -r -p "Enter new password for $username: " new_password
                echo
                read -s -r -p "Confirm new password: " new_password_confirm
                echo
                if [ "$new_password" != "$new_password_confirm" ]; then
                    echo "Error: Passwords do not match. Please try again."
                    continue
                fi
                if validate_password "$new_password" "$username"; then
                    echo "$username:$new_password" | sudo chpasswd
                    if [ $? -eq 0 ]; then
                        echo "Password for user 	'$username	' changed successfully."
                        sudo passwd -e "$username" >/dev/null
                        log_action "MODIFY_USER_SUCCESS: Password changed for 	'$username	'."
                    else
                        echo "Error: Failed to change password for 	'$username	'."
                        log_action "MODIFY_USER_FAILED: chpasswd failed for 	'$username	'."
                    fi
                    break
                else
                    read -r -p "Do you want to try a different password? (y/n): " choice
                    if [[ "$choice" != "y" && "$choice" != "Y" ]]; then
                        log_action "MODIFY_USER_FAILED: Pwd validation failed for 	'$username	', aborted."
                        break
                    fi 
                fi
            done
            ;;
        2) # Change Login Shell
            local new_shell
            echo "Available shells:"
            grep -vE "^#|nologin|false" /etc/shells
            read -r -p "Enter new login shell for $username (e.g., /bin/bash): " new_shell
            if grep -qxF "$new_shell" /etc/shells; then
                sudo chsh -s "$new_shell" "$username"
                if [ $? -eq 0 ]; then
                    echo "Login shell for 	'$username	' changed to 	'$new_shell	'."
                    log_action "MODIFY_USER_SUCCESS: Shell changed to 	'$new_shell	' for 	'$username	'."
                else
                    echo "Error: Failed to change shell for 	'$username	'."
                    log_action "MODIFY_USER_FAILED: chsh command failed for 	'$username	'."
                fi
            else
                echo "Error: Invalid shell 	'$new_shell	'. Choose from available shells."
                log_action "MODIFY_USER_FAILED: Invalid shell 	'$new_shell	' for 	'$username	'."
            fi
            ;;
        3) # Set Account Expiry Date
            local expiry_date
            read -r -p "Enter account expiry date for 	'$username	' (YYYY-MM-DD): " expiry_date
            if [[ "$expiry_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
                sudo usermod -e "$expiry_date" "$username"
                if [ $? -eq 0 ]; then
                    echo "Account expiry for 	'$username	' set to 	'$expiry_date	'."
                    log_action "MODIFY_USER_SUCCESS: Expiry set to 	'$expiry_date	' for 	'$username	'."
                else
                    echo "Error: Failed to set expiry for 	'$username	'. Format YYYY-MM-DD."
                    log_action "MODIFY_USER_FAILED: usermod -e failed for 	'$username	'."
                fi
            else
                echo "Error: Invalid date format. Use YYYY-MM-DD."
                log_action "MODIFY_USER_FAILED: Invalid expiry date format for 	'$username	'."
            fi
            ;;
        4) # Lock Account
            sudo usermod -L "$username"
            if [ $? -eq 0 ]; then
                echo "Account 	'$username	' has been locked."
                log_action "MODIFY_USER_SUCCESS: Account 	'$username	' locked."
            else
                echo "Error: Failed to lock account 	'$username	'."
                log_action "MODIFY_USER_FAILED: usermod -L failed for 	'$username	'."
            fi
            ;;
        5) # Unlock Account
            sudo usermod -U "$username"
            if [ $? -eq 0 ]; then
                echo "Account 	'$username	' has been unlocked."
                log_action "MODIFY_USER_SUCCESS: Account 	'$username	' unlocked."
            else
                echo "Error: Failed to unlock account 	'$username	'."
                log_action "MODIFY_USER_FAILED: usermod -U failed for 	'$username	'."
            fi
            ;;
        *) 
            echo "Error: Invalid option selected."
            log_action "MODIFY_USER_FAILED: Invalid option 	'$option	' for 	'$username	'."
            return 1
            ;;
    esac
    return 0
}

list_existing_users() {
    echo "Current non-system users (UID >= 1000):"
    echo "-----------------------------------------"
    getent passwd | awk -F: 	'$3 >= 1000 && $3 < 65534 { printf "Username: %-15s UID: %-5s GID: %-5s Home: %-25s Shell: %s\n", $1, $3, $4, $6, $7 }	'
    if [ $? -ne 0 ]; then
        log_action "LIST_USERS_FAILED: Could not list users."
    else
        log_action "LIST_USERS_SUCCESS: Listed non-system users."
    fi
    echo "-----------------------------------------"
}

# This part is for testing if script is called directly.
# The main interface (secure_system.sh) will call these functions as sourced.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "User Management Script (Direct Execution - For Testing Only)"
    # Ensure log file is writable for testing direct execution if not root
    if [ ! -w "$LOG_FILE" ] && [ -f "$LOG_FILE" ]; then sudo chown "$(whoami)" "$LOG_FILE"; fi
    if [ ! -f "$LOG_FILE" ]; then touch "$LOG_FILE" && sudo chown "$(whoami)" "$LOG_FILE"; fi
    echo "Select an action: 1.Create 2.Delete 3.Modify 4.List 0.Exit"
    read -r -p "Enter choice: " direct_choice
    case "$direct_choice" in
        1) create_new_user ;; 
        2) delete_existing_user ;; 
        3) modify_existing_user ;; 
        4) list_existing_users ;; 
        0) echo "Exiting." ;; 
        *) echo "Invalid choice." ;; 
    esac
fi

