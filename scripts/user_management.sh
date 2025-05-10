#!/bin/bash

# Script for User Account Management (Core Functionality)
# Automates user creation, deletion, and modification with password policies and logging.

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
    # Attempt to source from a default location if this script is called directly for testing
    if [ -f "./config.sh" ]; then source "./config.sh"; 
    elif [ -f "../scripts/config.sh" ]; then source "../scripts/config.sh"; 
    else echo -e "${RED}[${BOLD}ERROR${RESET}${RED}]${RESET} Fallback configuration file not found." >&2; exit 1; fi
fi

# Variables from config (or defaults if not set)
LOG_FILE="${USER_MGMT_LOG:-/var/log/user_mgmt.log}"
PASSWORD_MIN_LEN="${PASSWORD_MIN_LENGTH:-10}"
PASSWORD_REGEX="${PASSWORD_COMPLEXITY_REGEX:-^(?=.*[a-z])(?=.*[A-Z])(?=.*[0-9])(?=.*[!@#$%^&*])}"

# --- Helper Functions ---

# Status message functions
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

# Logging function
log_action() {
    if [ ! -f "$LOG_FILE" ]; then
        sudo touch "$LOG_FILE"
        sudo chmod 640 "$LOG_FILE"
        # Attempt to set group ownership to adm, common for logs. Fallback if it fails.
        sudo chown root:adm "$LOG_FILE" 2>/dev/null || sudo chown root:root "$LOG_FILE" 2>/dev/null
        if [ $? -ne 0 ]; then echo_warn "Could not set ownership for $LOG_FILE"; fi
    fi
    local effective_user="${SUDO_USER:-$(whoami)}"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - User: $effective_user - Action: $1" | sudo tee -a "$LOG_FILE" > /dev/null
}

# Password validation function with progress indicator
validate_password() {
    local password="$1"
    local username="$2"
    local valid=true
    local issues=()

    echo -e "${CYAN}▹ ${RESET}${BOLD}Validating password...${RESET}"
    
    # Check length
    echo -ne "  ${GRAY}▸ ${RESET}Length (min $PASSWORD_MIN_LEN chars): "
    if [ ${#password} -lt "$PASSWORD_MIN_LEN" ]; then
        echo -e "${RED}✗ Failed${RESET}"
        issues+=("Password must be at least $PASSWORD_MIN_LEN characters long")
        valid=false
    else
        echo -e "${GREEN}✓ Passed${RESET}"
    fi
    
    # Check complexity
    echo -ne "  ${GRAY}▸ ${RESET}Complexity: "
    if ! echo "$password" | grep -qP "$PASSWORD_REGEX"; then
        echo -e "${RED}✗ Failed${RESET}"
        issues+=("Password does not meet complexity requirements (lowercase, uppercase, number, and special character)")
        valid=false
    else
        echo -e "${GREEN}✓ Passed${RESET}"
    fi
    
    # Check if contains username
    if [ -n "$username" ]; then
        echo -ne "  ${GRAY}▸ ${RESET}Username check: "
        if echo "$password" | grep -iq "$username"; then
            echo -e "${RED}✗ Failed${RESET}"
            issues+=("Password cannot contain the username")
            valid=false
        else
            echo -e "${GREEN}✓ Passed${RESET}"
        fi
    fi
    
    # Show summary if issues found
    if [ "$valid" = false ]; then
        echo
        echo -e "${YELLOW}${BOLD}Password validation failed:${RESET}"
        for issue in "${issues[@]}"; do
            echo -e "  ${RED}• ${RESET}$issue"
        done
        echo -e "  ${CYAN}• ${RESET}Requirement: Must include lowercase, uppercase, number, and a special character (e.g., !@#$%^&*)."
        return 1
    fi
    
    echo -e "  ${GRAY}▸ ${RESET}Overall: ${GREEN}✓ Password meets all requirements${RESET}"
    return 0
}

# --- User Management Functions (Core) ---

create_new_user() {
    local username
    local password

    echo -e "${CYAN}▹ ${RESET}${BOLD}Create New User${RESET}"
    echo -e "${GRAY}This will create a new system user with a home directory and secure password.${RESET}"
    echo
    
    read -r -p "Enter username to create: " username
    if [ -z "$username" ]; then
        echo_error "Username cannot be empty."
        log_action "CREATE_USER_FAILED: Empty username provided."
        return 1
    fi

    if id "$username" &>/dev/null; then
        echo_error "User '$username' already exists."
        log_action "CREATE_USER_FAILED: User '$username' already exists."
        return 1
    fi

    while true; do
        read -s -r -p "Enter password for $username: " password
        echo
        read -s -r -p "Confirm password: " password_confirm
        echo
        echo

        if [ "$password" != "$password_confirm" ]; then
            echo_error "Passwords do not match. Please try again."
            continue
        fi

        if validate_password "$password" "$username"; then
            break
        else
            echo
            read -r -p "Do you want to try a different password? (${GREEN}y${RESET}/${RED}n${RESET}): " choice
            if [[ "$choice" != "y" && "$choice" != "Y" ]]; then
                log_action "CREATE_USER_FAILED: Password validation failed for '$username', user aborted."
                return 1
            fi 
        fi
    done

    echo -ne "${CYAN}▹ ${RESET}Creating user ${BOLD}$username${RESET}... "
    sudo useradd -m -s /bin/bash "$username"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed ✗${RESET}"
        echo_error "Failed to create user '$username'. Check system logs."
        log_action "CREATE_USER_FAILED: useradd command failed for '$username'."
        return 1
    fi
    echo -e "${GREEN}Done ✓${RESET}"

    echo -ne "${CYAN}▹ ${RESET}Setting password for ${BOLD}$username${RESET}... "
    echo "$username:$password" | sudo chpasswd
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed ✗${RESET}"
        echo_error "Failed to set password for user '$username'."
        echo -ne "${CYAN}▹ ${RESET}Removing incomplete user account... "
        sudo userdel -r "$username" 2>/dev/null 
        echo -e "${YELLOW}Done ✓${RESET}"
        log_action "CREATE_USER_FAILED: chpasswd command failed for '$username'. User removed."
        return 1
    fi
    echo -e "${GREEN}Done ✓${RESET}"

    echo -ne "${CYAN}▹ ${RESET}Setting password expiry (force change on first login)... "
    sudo passwd -e "$username" >/dev/null
    echo -e "${GREEN}Done ✓${RESET}"

    echo
    echo_success "User '$username' created successfully"
    echo -e "${GRAY}Password must be changed on first login.${RESET}"
    log_action "CREATE_USER_SUCCESS: User '$username' created."
    return 0
}

delete_existing_user() {
    local username
    local remove_home_dir_choice

    echo -e "${CYAN}▹ ${RESET}${BOLD}Delete Existing User${RESET}"
    echo -e "${GRAY}This will remove a user account from the system.${RESET}"
    echo

    read -r -p "Enter username to delete: " username
    if [ -z "$username" ]; then
        echo_error "Username cannot be empty."
        log_action "DELETE_USER_FAILED: Empty username provided."
        return 1
    fi

    if ! id "$username" &>/dev/null; then
        echo_error "User '$username' does not exist."
        log_action "DELETE_USER_FAILED: User '$username' does not exist."
        return 1
    fi

    if [ "$username" == "root" ] || [ "$username" == "$(whoami)" ] || [ "$username" == "${SUDO_USER:-$(whoami)}" ]; then
        echo_error "Deleting user '$username' is not allowed."
        log_action "DELETE_USER_FAILED: Attempt to delete critical user '$username'."
        return 1
    fi

    echo -e "${BRIGHT_YELLOW}${BOLD}⚠ Warning:${RESET} ${YELLOW}You are about to delete user account '${BOLD}$username${RESET}${YELLOW}'.${RESET}"
    read -r -p "Do you want to remove the home directory for '$username'? (${GREEN}yes${RESET}/${RED}no${RESET}) [no]: " remove_home_dir_choice

    echo

    if [[ "$remove_home_dir_choice" == "yes" || "$remove_home_dir_choice" == "YES" ]]; then
        echo -ne "${CYAN}▹ ${RESET}Deleting user ${BOLD}$username${RESET} with home directory... "
        sudo userdel -r "$username"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Done ✓${RESET}"
            echo_success "User '$username' and their home directory have been deleted."
            log_action "DELETE_USER_SUCCESS: User '$username' deleted with home directory."
        else
            echo -e "${RED}Failed ✗${RESET}"
            echo_error "Failed to delete user '$username' with home directory. Check system logs."
            log_action "DELETE_USER_FAILED: userdel -r command failed for '$username'."
            return 1
        fi
    else
        echo -ne "${CYAN}▹ ${RESET}Deleting user ${BOLD}$username${RESET} (preserving home directory)... "
        sudo userdel "$username"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Done ✓${RESET}"
            echo_success "User '$username' has been deleted. Home directory preserved."
            log_action "DELETE_USER_SUCCESS: User '$username' deleted. Home directory preserved."
        else
            echo -e "${RED}Failed ✗${RESET}"
            echo_error "Failed to delete user '$username'. Check system logs."
            log_action "DELETE_USER_FAILED: userdel command failed for '$username'."
            return 1
        fi
    fi
    return 0
}

modify_existing_user() {
    local username
    local option

    echo -e "${CYAN}▹ ${RESET}${BOLD}Modify Existing User${RESET}"
    echo -e "${GRAY}This will modify properties of an existing user account.${RESET}"
    echo

    read -r -p "Enter username to modify: " username
    if [ -z "$username" ]; then
        echo_error "Username cannot be empty."
        log_action "MODIFY_USER_FAILED: Empty username for modification."
        return 1
    fi

    if ! id "$username" &>/dev/null; then
        echo_error "User '$username' does not exist."
        log_action "MODIFY_USER_FAILED: User '$username' for modification does not exist."
        return 1
    fi

    echo
    echo -e "${BRIGHT_WHITE}${BOLD}User Modification Options for '$username':${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "  ${BLUE}1.${RESET} ${BOLD}Change Password${RESET}       Set a new password with security checks"
    echo -e "  ${BLUE}2.${RESET} ${BOLD}Change Login Shell${RESET}    Modify the user's shell environment"
    echo -e "  ${BLUE}3.${RESET} ${BOLD}Set Account Expiry${RESET}    Set a date when the account will expire"
    echo -e "  ${BLUE}4.${RESET} ${BOLD}Lock Account${RESET}          Prevent the user from logging in"
    echo -e "  ${BLUE}5.${RESET} ${BOLD}Unlock Account${RESET}        Re-enable a locked account"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo
    
    read -r -p "Select an option (1-5): " option

    case "$option" in
        1) # Change Password
            local new_password
            echo
            echo -e "${CYAN}▹ ${RESET}${BOLD}Change Password for $username${RESET}"
            echo -e "${GRAY}This will set a new password for the user account.${RESET}"
            echo
            
            while true; do
                read -s -r -p "Enter new password for $username: " new_password
                echo
                read -s -r -p "Confirm new password: " new_password_confirm
                echo
                echo
                
                if [ "$new_password" != "$new_password_confirm" ]; then
                    echo_error "Passwords do not match. Please try again."
                    continue
                fi
                
                if validate_password "$new_password" "$username"; then
                    echo -ne "${CYAN}▹ ${RESET}Setting new password for ${BOLD}$username${RESET}... "
                    echo "$username:$new_password" | sudo chpasswd
                    if [ $? -eq 0 ]; then
                        echo -e "${GREEN}Done ✓${RESET}"
                        echo -ne "${CYAN}▹ ${RESET}Setting password expiry (force change on next login)... "
                        sudo passwd -e "$username" >/dev/null
                        echo -e "${GREEN}Done ✓${RESET}"
                        echo_success "Password for user '$username' changed successfully."
                        log_action "MODIFY_USER_SUCCESS: Password changed for '$username'."
                    else
                        echo -e "${RED}Failed ✗${RESET}"
                        echo_error "Failed to change password for '$username'."
                        log_action "MODIFY_USER_FAILED: chpasswd failed for '$username'."
                    fi
                    break
                else
                    echo
                    read -r -p "Do you want to try a different password? (${GREEN}y${RESET}/${RED}n${RESET}): " choice
                    if [[ "$choice" != "y" && "$choice" != "Y" ]]; then
                        log_action "MODIFY_USER_FAILED: Pwd validation failed for '$username', aborted."
                        break
                    fi 
                fi
            done
            ;;
        2) # Change Login Shell
            local new_shell
            echo
            echo -e "${CYAN}▹ ${RESET}${BOLD}Change Login Shell for $username${RESET}"
            echo -e "${GRAY}This will set a new shell for the user account.${RESET}"
            echo
            
            echo -e "${BRIGHT_WHITE}Available shells:${RESET}"
            grep -vE "^#|nologin|false" /etc/shells | sed "s|^|  ${GREEN}•${RESET} |"
            echo
            
            read -r -p "Enter new login shell for $username (e.g., /bin/bash): " new_shell
            
            if grep -qxF "$new_shell" /etc/shells; then
                echo -ne "${CYAN}▹ ${RESET}Changing shell for ${BOLD}$username${RESET} to ${BOLD}$new_shell${RESET}... "
                sudo chsh -s "$new_shell" "$username"
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}Done ✓${RESET}"
                    echo_success "Login shell for '$username' changed to '$new_shell'."
                    log_action "MODIFY_USER_SUCCESS: Shell changed to '$new_shell' for '$username'."
                else
                    echo -e "${RED}Failed ✗${RESET}"
                    echo_error "Failed to change shell for '$username'."
                    log_action "MODIFY_USER_FAILED: chsh command failed for '$username'."
                fi
            else
                echo_error "Invalid shell '$new_shell'. Choose from available shells."
                log_action "MODIFY_USER_FAILED: Invalid shell '$new_shell' for '$username'."
            fi
            ;;
        3) # Set Account Expiry Date
            local expiry_date
            echo
            echo -e "${CYAN}▹ ${RESET}${BOLD}Set Account Expiry for $username${RESET}"
            echo -e "${GRAY}This will set an expiration date for the user account.${RESET}"
            echo -e "${GRAY}After this date, the account will be automatically locked.${RESET}"
            echo
            
            read -r -p "Enter account expiry date for '$username' (YYYY-MM-DD): " expiry_date
            
            if [[ "$expiry_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
                echo -ne "${CYAN}▹ ${RESET}Setting account expiry for ${BOLD}$username${RESET} to ${BOLD}$expiry_date${RESET}... "
                sudo usermod -e "$expiry_date" "$username"
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}Done ✓${RESET}"
                    echo_success "Account expiry for '$username' set to '$expiry_date'."
                    log_action "MODIFY_USER_SUCCESS: Expiry set to '$expiry_date' for '$username'."
                else
                    echo -e "${RED}Failed ✗${RESET}"
                    echo_error "Failed to set expiry for '$username'. Format YYYY-MM-DD."
                    log_action "MODIFY_USER_FAILED: usermod -e failed for '$username'."
                fi
            else
                echo_error "Invalid date format. Use YYYY-MM-DD."
                log_action "MODIFY_USER_FAILED: Invalid expiry date format for '$username'."
            fi
            ;;
        4) # Lock Account
            echo
            echo -e "${CYAN}▹ ${RESET}${BOLD}Lock Account for $username${RESET}"
            echo -e "${GRAY}This will prevent the user from logging in without deleting the account.${RESET}"
            echo
            
            echo -ne "${CYAN}▹ ${RESET}Locking account for ${BOLD}$username${RESET}... "
            sudo usermod -L "$username"
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Done ✓${RESET}"
                echo_success "Account '$username' has been locked."
                log_action "MODIFY_USER_SUCCESS: Account '$username' locked."
            else
                echo -e "${RED}Failed ✗${RESET}"
                echo_error "Failed to lock account '$username'."
                log_action "MODIFY_USER_FAILED: usermod -L failed for '$username'."
            fi
            ;;
        5) # Unlock Account
            echo
            echo -e "${CYAN}▹ ${RESET}${BOLD}Unlock Account for $username${RESET}"
            echo -e "${GRAY}This will re-enable a previously locked account.${RESET}"
            echo
            
            echo -ne "${CYAN}▹ ${RESET}Unlocking account for ${BOLD}$username${RESET}... "
            sudo usermod -U "$username"
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Done ✓${RESET}"
                echo_success "Account '$username' has been unlocked."
                log_action "MODIFY_USER_SUCCESS: Account '$username' unlocked."
            else
                echo -e "${RED}Failed ✗${RESET}"
                echo_error "Failed to unlock account '$username'."
                log_action "MODIFY_USER_FAILED: usermod -U failed for '$username'."
            fi
            ;;
        *) 
            echo_error "Invalid option selected."
            log_action "MODIFY_USER_FAILED: Invalid option '$option' for '$username'."
            return 1
            ;;
    esac
    return 0
}

list_existing_users() {
    echo -e "${CYAN}▹ ${RESET}${BOLD}Current System Users${RESET}"
    echo -e "${GRAY}Displaying all non-system users (UID >= 1000)${RESET}"
    echo

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BRIGHT_WHITE}${BOLD}USERNAME          UID     GID     HOME DIRECTORY              SHELL${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    
    getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 {print}' | while read -r line; do
        username=$(echo "$line" | cut -d: -f1)
        uid=$(echo "$line" | cut -d: -f3)
        gid=$(echo "$line" | cut -d: -f4)
        home=$(echo "$line" | cut -d: -f6)
        shell=$(echo "$line" | cut -d: -f7)
        
        # Check if account is locked
        if sudo passwd -S "$username" 2>/dev/null | grep -q "locked"; then
            status="${RED}LOCKED${RESET}"
        else
            status="${GREEN}ACTIVE${RESET}"
        fi
        
        printf "${BRIGHT_WHITE}%-16s${RESET} ${BLUE}%-7s${RESET} %-7s %-25s %-20s ${status}\n" "$username" "$uid" "$gid" "$home" "$shell"
    done
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    
    if [ $? -ne 0 ]; then
        log_action "LIST_USERS_FAILED: Could not list users."
    else
        log_action "LIST_USERS_SUCCESS: Listed non-system users."
    fi
}

# This part is for testing if script is called directly.
# The main interface (secure_system.sh) will call these functions as sourced.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo -e "${BLUE}${BOLD}User Management Script${RESET} ${GRAY}(Direct Execution - For Testing Only)${RESET}"
    # Ensure log file is writable for testing direct execution if not root
    if [ ! -w "$LOG_FILE" ] && [ -f "$LOG_FILE" ]; then sudo chown "$(whoami)" "$LOG_FILE"; fi
    if [ ! -f "$LOG_FILE" ]; then touch "$LOG_FILE" && sudo chown "$(whoami)" "$LOG_FILE"; fi
    
    echo
    echo -e "${BRIGHT_WHITE}${BOLD}Select an action:${RESET}"
    echo -e "  ${BLUE}1.${RESET} ${BOLD}Create User${RESET}"
    echo -e "  ${BLUE}2.${RESET} ${BOLD}Delete User${RESET}"
    echo -e "  ${BLUE}3.${RESET} ${BOLD}Modify User${RESET}"
    echo -e "  ${BLUE}4.${RESET} ${BOLD}List Users${RESET}"
    echo -e "  ${RED}0.${RESET} ${BOLD}Exit${RESET}"
    echo
    
    read -r -p "Enter choice: " direct_choice
    echo
    
    case "$direct_choice" in
        1) create_new_user ;; 
        2) delete_existing_user ;; 
        3) modify_existing_user ;; 
        4) list_existing_users ;; 
        0) echo -e "${GRAY}Exiting.${RESET}" ;; 
        *) echo_error "Invalid choice." ;; 
    esac
fi

