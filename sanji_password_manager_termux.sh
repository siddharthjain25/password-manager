#!/data/data/com.termux/files/usr/bin/bash

# Path for the SQLite database file
db_file="$HOME/.config/sanji-pm-data.db"
backup_dir="$HOME/.config/sanji-pm-backups"
backup_file="$backup_dir/sanji-pm-backup.db"
encrypted_backup_file="$backup_dir/sanji-pm-backup.enc"
restored_db_file="$backup_dir/restored_sanji-pm-backup.db"

# Color codes for styling output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Menu options
options=("Add a new password" "Retrieve a password" "Update a password" "Delete a password" "List all accounts" "Backup data" "Restore data" "Exit")

# Function to print the menu
print_menu() {
    echo -e "${CYAN}Password Manager Menu:${NC}"
    for i in "${!options[@]}"; do
        if [ "$i" -eq "$menu_index" ]; then
            echo -e "${YELLOW}> ${options[$i]}${NC}"  # Highlight the selected option
        else
            echo "  ${options[$i]}"
        fi
    done
}

# Initialize the SQLite database if it doesn't exist
initialize_db() {
    sqlite3 "$db_file" <<EOF
CREATE TABLE IF NOT EXISTS accounts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    account_name TEXT NOT NULL,
    email TEXT,
    username TEXT,
    mobile_number TEXT,
    notes TEXT,
    password TEXT NOT NULL
);
EOF
}

# Function to encrypt the password
encrypt_password() {
    echo "$1" | openssl enc -aes-256-cbc -a -salt -pbkdf2 -pass pass:"$2"
}

# Function to decrypt the password
decrypt_password() {
    echo "$1" | openssl enc -aes-256-cbc -d -a -pbkdf2 -pass pass:"$2"
}

# Function to prompt for the encryption key
get_encryption_key() {
    read -sp "Enter cypher key: " encryption_key
    echo
}

# Function to create a local encrypted backup
backup_data() {
    if [ ! -d "$backup_dir" ]; then
        mkdir -p "$backup_dir"
    fi
    cp "$db_file" "$backup_file"
    get_encryption_key
    openssl enc -aes-256-cbc -a -salt -pbkdf2 -in "$backup_file" -out "$encrypted_backup_file" -pass pass:"$encryption_key"
    rm "$backup_file"
    echo -e "${GREEN}Backup created and encrypted at $encrypted_backup_file.${NC}"
    read -rp "Press any key to return to the menu..." -n 1
}

# Function to restore data from an encrypted backup
restore_data() {
    read -p "Enter the path to the encrypted backup file: " encrypted_backup_file
    if [ ! -f "$encrypted_backup_file" ]; then
        echo -e "${RED}No backup file found at $encrypted_backup_file.${NC}"
        read -rp "Press any key to return to the menu..." -n 1
        return
    fi

    get_encryption_key

    # Attempt to decrypt the backup file, suppressing error output
    openssl enc -aes-256-cbc -d -a -pbkdf2 -in "$encrypted_backup_file" -out "$restored_db_file" -pass pass:"$encryption_key" 2>/dev/null
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to decrypt backup. Please check the cypher key.${NC}"
        read -rp "Press any key to return to the menu..." -n 1
        return
    fi

    mv "$restored_db_file" "$db_file"
    echo -e "${GREEN}Backup restored successfully. Current database replaced with the restored backup.${NC}"
    read -rp "Press any key to return to the menu..." -n 1
}

# Function to add user data
add_password() {
    read -p "Enter account name: " account_name
    read -p "Enter email: " email
    read -p "Enter username: " username
    read -p "Enter mobile number: " mobile_number
    read -p "Enter notes: " notes
    read -sp "Password: " password
    echo
    get_encryption_key
    echo
    encrypted_password=$(encrypt_password "$password" "$encryption_key")
    sqlite3 "$db_file" <<EOF
INSERT INTO accounts (account_name, email, username, mobile_number, notes, password)
VALUES ('$account_name', '$email', '$username', '$mobile_number', '$notes', '$encrypted_password');
EOF
    echo -e "${GREEN}Details for $account_name saved.${NC}"
    read -rp "Press any key to return to the menu..." -n 1
}

# Function to retrieve data
get_password() {
    echo "Saved accounts:"
    # List accounts with null byte removal
    echo -e "${YELLOW}"
    sqlite3 "$db_file" "SELECT id, account_name FROM accounts;" | tr -d '\0'
    echo -e "${NC}"
    read -p "Enter account ID: " id
    get_encryption_key
    record=$(sqlite3 "$db_file" "SELECT account_name, email, username, mobile_number, notes, password FROM accounts WHERE id = $id;")
    if [ -n "$record" ]; then
        account_name=$(echo "$record" | tr -d '\0' | awk -F '|' '{print $1}')
        email=$(echo "$record" | tr -d '\0' | awk -F '|' '{print $2}')
        username=$(echo "$record" | tr -d '\0' | awk -F '|' '{print $3}')
        mobile_number=$(echo "$record" | tr -d '\0' | awk -F '|' '{print $4}')
        notes=$(echo "$record" | tr -d '\0' | awk -F '|' '{print $5}')
        encrypted_password=$(echo "$record" | tr -d '\0' | awk -F '|' '{print $6}')
        
        if password=$(decrypt_password "$encrypted_password" "$encryption_key" 2>/dev/null); then
            max_length=$(echo -e "$account_name\n$email\n$username\n$mobile_number\n$notes\nPassword: $password" | awk '{ if (length > max) max = length } END { print max }')
            box_width=$((max_length + 4))

            echo -e "${GREEN}"
            echo -e "Account Name: $account_name"
            echo -e "Email: $email"
            echo -e "Username: $username"
            echo -e "Mobile Number: $mobile_number"
            echo -e "Notes: $notes"
            echo -e "Password: $password"
            echo -e "${NC}"
            # Pause and wait for user input before clearing the screen
            read -rp "Press any key to return to the menu..." -n 1
        else
            echo "Cypher key is incorrect. Aborting retrieval."
            exit 1
        fi
    else
        echo -e "${RED}Account not found or decryption failed.${NC}"
        read -rp "Press any key to return to the menu..." -n 1
    fi
}

# Function to delete data
delete_data() {
    echo "Saved accounts:"
    # List accounts with null byte removal
    echo -e "${YELLOW}"
    sqlite3 "$db_file" "SELECT id, account_name FROM accounts;" | tr -d '\0'
    echo -e "${NC}"
    read -p "Enter account ID: " id
    get_encryption_key
    record=$(sqlite3 "$db_file" "SELECT password FROM accounts WHERE id = $id;")
    account_name=$(sqlite3 "$db_file" "SELECT account_name FROM accounts WHERE id = $id;")
    
    if [ -n "$record" ]; then
        encrypted_password=$(echo "$record" | awk -F '|' '{print $1}')
        if decrypted_password=$(decrypt_password "$encrypted_password" "$encryption_key" 2>/dev/null); then
            # Ask for confirmation before deletion
            echo -e "${RED}Are you sure you want to delete account '$account_name' (ID: $id)? This action cannot be undone.${NC}"
            read -p "Type 'yes' to confirm: " confirmation
            if [ "$confirmation" == "yes" ]; then
                if sqlite3 "$db_file" "DELETE FROM accounts WHERE id = $id;"; then
                    echo -e "${GREEN}User details for account $account_name deleted successfully.${NC}"
                    read -rp "Press any key to return to the menu..." -n 1
                else
                    echo -e "${RED}Error: Failed to delete account.${NC}"
                fi
            else
                echo -e "${YELLOW}Deletion aborted.${NC}"
                read -rp "Press any key to return to the menu..." -n 1
            fi
        else
            echo -e "${RED}Cypher key is incorrect. Aborting deletion.${NC}"
            exit 1
        fi
    else
        echo -e "${RED}Account not found or decryption failed.${NC}"
        read -rp "Press any key to return to the menu..." -n 1
    fi
}

# Function to update data
update_password() {
    echo "Saved accounts:"
    # List accounts with null byte removal
    echo -e "${YELLOW}"
    sqlite3 "$db_file" "SELECT id, account_name FROM accounts;" | tr -d '\0'
    echo -e "${NC}"
    read -p "Enter account ID: " id
    get_encryption_key
    record=$(sqlite3 "$db_file" "SELECT account_name, email, username, mobile_number, notes, password FROM accounts WHERE id = $id;")
    if [ -n "$record" ]; then
        account_name=$(echo "$record" | awk -F '|' '{print $1}')
        email=$(echo "$record" | awk -F '|' '{print $2}')
        username=$(echo "$record" | awk -F '|' '{print $3}')
        mobile_number=$(echo "$record" | awk -F '|' '{print $4}')
        notes=$(echo "$record" | awk -F '|' '{print $5}')
        encrypted_password=$(echo "$record" | awk -F '|' '{print $6}')
        
        if password=$(decrypt_password "$encrypted_password" "$encryption_key" 2>/dev/null); then
            echo "Current details for account ID '$id':"
            echo "--------------------------------------"
            echo "Account Name: $account_name"
            echo "Email: $email"
            echo "Username: $username"
            echo "Mobile Number: $mobile_number"
            echo "Notes: $notes"
            echo "Password: $password"
            echo "--------------------------------------"

            read -p "Enter new account name [$account_name]: " new_account_name
            read -p "Enter new email [$email]: " new_email
            read -p "Enter new username [$username]: " new_username
            read -p "Enter new mobile number [$mobile_number]: " new_mobile_number
            read -p "Enter new notes [$notes]: " new_notes
            read -sp "Enter new password (press Enter to keep current): " new_password
            echo

            new_account_name=${new_account_name:-$account_name}
            new_email=${new_email:-$email}
            new_username=${new_username:-$username}
            new_mobile_number=${new_mobile_number:-$mobile_number}
            new_notes=${new_notes:-$notes}
            if [ -n "$new_password" ]; then
                encrypted_password=$(encrypt_password "$new_password" "$encryption_key")
            else
                encrypted_password=$encrypted_password
            fi

            sqlite3 "$db_file" <<EOF
UPDATE accounts
SET account_name = '$new_account_name',
    email = '$new_email',
    username = '$new_username',
    mobile_number = '$new_mobile_number',
    notes = '$new_notes',
    password = '$encrypted_password'
WHERE id = $id;
EOF
            echo -e "${GREEN}Details updated for account $new_account_name.${NC}"

            # Pause and wait for user input before clearing the screen
            read -rp "Press any key to return to the menu..." -n 1
        else
            echo -e "${RED}Cypher key is incorrect. Aborting update.${NC}"
            exit 1
        fi
    else
        echo "${RED}Account not found or decryption failed.${NC}"
    fi
}

# Function to list all accounts
list_accounts() {
    if [ -s "$db_file" ]; then
        echo -e "Saved accounts:"
        # List accounts with null byte removal
        echo -e "${YELLOW}"
        sqlite3 "$db_file" "SELECT id, account_name FROM accounts;" | tr -d '\0'
        echo -e "${NC}"
    else
        echo -e "${RED}No accounts saved ${NC}"
    fi

    # Pause and wait for user input before clearing the screen
    read -rp "Press any key to return to the menu..." -n 1
}

# Initialize the database if not exists
initialize_db

# Function to handle the menu selection
handle_menu_selection() {
    case $menu_index in
        0) add_password ;;
        1) get_password ;;
        2) update_password ;;
        3) delete_data ;;
        4) list_accounts ;;
        5) backup_data ;;
        6) restore_data ;;
        7) exit 0 ;;
    esac
}

# Main menu loop
menu_index=0
key=""
while true; do
    clear
    print_menu

    # Read user input
    read -rsn1 key  # Read a single character

    # Handle arrow key input
    if [[ $key == $'\x1b' ]]; then
        read -rsn2 -t 0.1 key  # Read 2 more characters (for arrow keys)
        if [[ $key == "[A" ]]; then
            # Up arrow
            ((menu_index--))
            if [ "$menu_index" -lt 0 ]; then
                menu_index=$((${#options[@]} - 1))
            fi
        elif [[ $key == "[B" ]]; then
            # Down arrow
            ((menu_index++))
            if [ "$menu_index" -ge "${#options[@]}" ]; then
                menu_index=0
            fi
        fi
    elif [[ $key == "" ]]; then
        # Enter key
        handle_menu_selection
    fi
done