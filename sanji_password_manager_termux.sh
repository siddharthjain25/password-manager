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

# Function to print the menu and get the user's choice using fzf
select_option() {
    local choice
    choice=$(printf "%s\n" "${options[@]}" | fzf --height=100% --cycle --tac --border=bold --prompt="Search an option: ")
    echo "$choice"
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
    backup_files=($(ls -1 "$backup_dir"/*.enc 2>/dev/null))
    selected_backup=$(printf "%s\n" "${backup_files[@]}" | fzf --height=100% --border=bold --prompt="Select a backup file: " --preview "echo {}" --preview-window=up:1:wrap)

    if [ -z "$selected_backup" ]; then
        echo -e "${RED}No backup file selected.${NC}"
        read -rp "Press any key to return to the menu..." -n 1
        return
    fi

    get_encryption_key

    # Attempt to decrypt the backup file, suppressing error output
    openssl enc -aes-256-cbc -d -a -pbkdf2 -in "$selected_backup" -out "$restored_db_file" -pass pass:"$encryption_key" 2>/dev/null

    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to decrypt backup. Please check the cypher key.${NC}"
        read -rp "Press any key to return to the menu..." -n 1
        return
    fi

    mv "$restored_db_file" "$db_file"
    echo -e "${GREEN}Backup restored successfully. Current database replaced with the restored backup.${NC}"
    read -rp "Press any key to return to the menu..." -n 1
}

add_password() {
    account_name=$(printf "" | fzf --height=100% --no-mouse --disabled --border=bold --prompt="Enter account name: " --print-query --expect=enter | head -n 1)
    email=$(printf "Account name: $account_name" | fzf --height=100% --no-mouse --disabled --tac --border=bold --prompt="Enter email: " --print-query --expect=enter | head -n 1)
    username=$(printf "Account name: $account_name\nEmail: $email" | fzf --height=100% --no-mouse --disabled --tac --border=bold --prompt="Enter username: " --print-query --expect=enter | head -n 1)
    mobile_number=$(printf "Account name: $account_name\nEmail: $email\nUsername: $username" | fzf --height=100% --no-mouse --disabled --tac --border=bold --prompt="Enter mobile number: " --print-query --expect=enter | head -n 1)
    notes=$(printf "Account name: $account_name\nEmail: $email\nUsername: $username\nMobile Number: $mobile_number" | fzf --height=100% --no-mouse --disabled --tac --border=bold --prompt="Enter notes (optional): " --print-query --expect=enter | head -n 1)
    password=$(printf "Account name: $account_name\nEmail: $email\nUsername: $username\nMobile Number: $mobile_number\nNotes: $notes" | fzf --height=100% --no-mouse --disabled --tac --border=bold --prompt="Password: " --print-query --expect=enter | head -n 1)
    
    get_encryption_key
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
    clear
    # Fetch all accounts and display only IDs and account names
    mapfile -t accounts < <(sqlite3 "$db_file" "SELECT id, account_name FROM accounts;")
    if [ ${#accounts[@]} -eq 0 ]; then
        echo -e "${RED}No accounts saved.${NC}"
        read -rp "Press any key to return to the menu..." -n 1
        return
    fi

    selected_account=$(printf "%s\n" "${accounts[@]}" | fzf --height=100% --cycle --tac --border=bold --prompt="Search an account: " --preview "echo {}" --preview-window=up:1:wrap)

    if [ -z "$selected_account" ]; then
        echo -e "${RED}No account selected.${NC}"
        read -rp "Press any key to return to the menu..." -n 1
        return
    fi

    # Extract the ID (the first field before the pipe '|')
    account_id=$(echo "$selected_account" | awk -F '|' '{print $1}')

    # Fetch account details using just the ID
    get_encryption_key
    record=$(sqlite3 "$db_file" "SELECT account_name, email, username, mobile_number, notes, password FROM accounts WHERE id = $account_id;")

    if [ -n "$record" ]; then
        account_name=$(echo "$record" | awk -F '|' '{print $1}')
        email=$(echo "$record" | awk -F '|' '{print $2}')
        username=$(echo "$record" | awk -F '|' '{print $3}')
        mobile_number=$(echo "$record" | awk -F '|' '{print $4}')
        notes=$(echo "$record" | awk -F '|' '{print $5}')
        encrypted_password=$(echo "$record" | awk -F '|' '{print $6}')

        if password=$(decrypt_password "$encrypted_password" "$encryption_key" 2>/dev/null); then
            printf "%s\n" "Account details for $account_name:" "Account Name: ${account_name}" "Email: ${email}" "Username: ${username}" "Mobile Number: ${mobile_number}" "Notes: ${notes}" "Password: ${password}" | fzf --tac --height=100% --cycle --border=bold --no-mouse --prompt="Press any key to return to the menu..." 
        else
            echo -e "${RED}Failed to decrypt password. Incorrect cypher key.${NC}"
            read -rp "Press any key to return to the menu..." -n 1
        fi
    else
        echo -e "${RED}Account not found.${NC}"
        read -rp "Press any key to return to the menu..." -n 1
    fi
}

# Function to delete data
delete_data() {
    # List accounts for selection
    mapfile -t accounts < <(sqlite3 "$db_file" "SELECT id, account_name FROM accounts;")
    if [ ${#accounts[@]} -eq 0 ]; then
        echo -e "${RED}No accounts saved.${NC}"
        read -rp "Press any key to return to the menu..." -n 1
        return
    fi

    selected_account=$(printf "%s\n" "${accounts[@]}" | fzf --height=100% --cycle --tac --border=bold --prompt="Search & select an account to delete: " --preview "echo {}" --preview-window=up:1:wrap)

    if [ -z "$selected_account" ]; then
        clear
        echo -e "${RED}No account selected.${NC}"
        read -rp "Press any key to return to the menu..." -n 1
        return
    fi

    # Extract the ID (the first field before the pipe '|')
    account_id=$(echo "$selected_account" | awk -F '|' '{print $1}')

    get_encryption_key
    record=$(sqlite3 "$db_file" "SELECT password FROM accounts WHERE id = $account_id;")
    account_name=$(sqlite3 "$db_file" "SELECT account_name FROM accounts WHERE id = $account_id;")

    if [ -n "$record" ]; then
        encrypted_password=$(echo "$record" | awk -F '|' '{print $1}')

        if password=$(decrypt_password "$encrypted_password" "$encryption_key" 2>/dev/null); then
            read -p "Are you sure you want to delete the account '$account_name'? (y/n): " confirm
            if [[ $confirm == [yY] ]]; then
                sqlite3 "$db_file" "DELETE FROM accounts WHERE id = $account_id;"
                echo -e "${GREEN}Account $account_name deleted.${NC}"
            else
                echo -e "${RED}Deletion aborted.${NC}"
            fi
        else
            echo -e "${RED}Cypher key is incorrect. Aborting deletion.${NC}"
        fi
    else
        echo -e "${RED}Account not found or decryption failed.${NC}"
        read -rp "Press any key to return to the menu..." -n 1
    fi

    # Pause and wait for user input before clearing the screen
    read -rp "Press any key to return to the menu..." -n 1
}

update_password() {
    # List accounts for selection
    mapfile -t accounts < <(sqlite3 "$db_file" "SELECT id || ' | ' || account_name FROM accounts;")
    if [ ${#accounts[@]} -eq 0 ]; then
        echo -e "${RED}No accounts saved.${NC}"
        read -rp "Press any key to return to the menu..." -n 1
        return
    fi

    selected_account=$(printf "%s\n" "${accounts[@]}" | fzf --height=100% --tac --cycle --border=bold --prompt="Search and select an account to update: " --preview "echo {}" --preview-window=up:1:wrap)

    if [ -z "$selected_account" ]; then
        echo -e "${RED}No account selected.${NC}"
        read -rp "Press any key to return to the menu..." -n 1
        return
    fi

    # Extract the ID (the first field before the pipe '|')
    account_id=$(echo "$selected_account" | awk -F ' | ' '{print $1}')

    get_encryption_key
    record=$(sqlite3 "$db_file" "SELECT account_name, email, username, mobile_number, notes, password FROM accounts WHERE id = $account_id;")
    if [ -n "$record" ]; then
        IFS='|' read -r account_name email username mobile_number notes encrypted_password <<< "$record"

        if password=$(decrypt_password "$encrypted_password" "$encryption_key" 2>/dev/null); then

            new_account_name=$(fzf --height=100% --no-mouse --disabled --border=bold --prompt="Enter new account name (press Enter to keep current): " --print-query --expect=enter <<< "Current account name: $account_name" | head -n 1)
            new_email=$(fzf --height=100% --no-mouse --disabled --border=bold --prompt="Enter new email (press Enter to keep current): " --print-query --expect=enter <<< "Current email: $email" | head -n 1)
            new_username=$(fzf --height=100% --no-mouse --disabled --border=bold --prompt="Enter new username (press Enter to keep current): " --print-query --expect=enter <<< "Current username: $username" | head -n 1)
            new_mobile_number=$(fzf --height=100% --no-mouse --disabled --border=bold --prompt="Enter new mobile number (press Enter to keep current): " --print-query --expect=enter <<< "Current mobile number: $mobile_number" | head -n 1)
            new_notes=$(fzf --height=100% --no-mouse --disabled --border=bold --prompt="Enter new note (optional): " --print-query --expect=enter <<< "Current note: $notes" | head -n 1)
            new_password=$(fzf --height=100% --no-mouse --disabled --border=bold --prompt="Enter new password (press Enter to keep current): " --print-query --expect=enter <<< "Current password: $password" | head -n 1)

            new_account_name=${new_account_name:-$account_name}
            new_email=${new_email:-$email}
            new_username=${new_username:-$username}
            new_mobile_number=${new_mobile_number:-$mobile_number}
            new_notes=${new_notes:-$notes}
            if [ -n "$new_password" ]; then
                encrypted_password=$(encrypt_password "$new_password" "$encryption_key")
            fi

            sqlite3 "$db_file" <<EOF
UPDATE accounts
SET account_name = '$new_account_name',
    email = '$new_email',
    username = '$new_username',
    mobile_number = '$new_mobile_number',
    notes = '$new_notes',
    password = '$encrypted_password'
WHERE id = $account_id;
EOF
            echo -e "${GREEN}Details updated for account $new_account_name.${NC}"

            # Pause and wait for user input before clearing the screen
            read -rp "Press any key to return to the menu..." -n 1
        else
            echo -e "${RED}Cypher key is incorrect. Aborting update.${NC}"
            read -rp "Press any key to return to the menu..." -n 1
        fi
    else
        echo -e "${RED}Account not found or decryption failed.${NC}"
        read -rp "Press any key to return to the menu..." -n 1
    fi
}

# Function to list all accounts
list_accounts() {
    if [ -s "$db_file" ]; then
        echo -e "Saved accounts:"
        # List accounts with null byte removal
        mapfile -t accounts < <(sqlite3 "$db_file" "SELECT id, account_name FROM accounts;" | tr -d '\0')
        if [ ${#accounts[@]} -eq 0 ]; then
            echo -e "${RED}No accounts saved.${NC}"
        else
            printf "%s\n" "${accounts[@]}" | fzf --height=100% --disabled --tac --border=bold --prompt="Press ENTER key to return to the menu..."
        fi
    else
        echo -e "${RED}No accounts saved.${NC}"
    fi
}

# Initialize the database if not exists
initialize_db

# Main menu loop with fzf integration
while true; do
    clear
    # Print menu options and get user selection using fzf
    selection=$(select_option)

    case "$selection" in
    "Add a new password") add_password ;;
    "Retrieve a password") get_password ;;
    "Update a password") update_password ;;
    "Delete a password") delete_data ;;
    "List all accounts") list_accounts ;;
    "Backup data") backup_data ;;
    "Restore data") restore_data ;;
    "Exit") clear && exit 0 ;;
    *) echo -e "${RED}Invalid selection. Please try again.${NC}" ;;
    esac
done