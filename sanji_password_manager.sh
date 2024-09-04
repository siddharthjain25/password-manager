#!/bin/bash

# Path for the SQLite database file && If your thinking about Blackleg Sanji from OnePiece then you are correct.
db_file="$HOME/.config/sanji-pm-data.db"

# Function to initialize the SQLite database
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

# Function to add user data
add_password() {
    read -p "Enter account name: " account_name
    read -p "Enter email: " email
    read -p "Enter username: " username
    read -p "Enter mobile number: " mobile_number
    read -p "Enter notes: " notes
    read -sp "Password: " password
    get_encryption_key
    echo
    encrypted_password=$(encrypt_password "$password" "$encryption_key")
    sqlite3 "$db_file" <<EOF
INSERT INTO accounts (account_name, email, username, mobile_number, notes, password)
VALUES ('$account_name', '$email', '$username', '$mobile_number', '$notes', '$encrypted_password');
EOF
    echo "Details for $account_name saved."
}

# Function to retrieve data
get_password() {
    list_accounts
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
        
        # Attempt to decrypt the password with the provided key
        if password=$(decrypt_password "$encrypted_password" "$encryption_key" 2>/dev/null); then
            # Calculate box width based on longest line
            max_length=$(echo -e "$account_name\n$email\n$username\n$mobile_number\n$notes\nPassword: $password" | awk '{ if (length > max) max = length } END { print max }')
            box_width=$((max_length + 4))

            # Print the top border
            printf '%*s\n' "$box_width" '' | tr ' ' '='

            # Print the details
            printf '| %-*s |\n' "$max_length" "Account Name: $account_name"
            printf '| %-*s |\n' "$max_length" "Email: $email"
            printf '| %-*s |\n' "$max_length" "Username: $username"
            printf '| %-*s |\n' "$max_length" "Mobile Number: $mobile_number"
            printf '| %-*s |\n' "$max_length" "Notes: $notes"
            printf '| %-*s |\n' "$max_length" "Password: $password"

            # Print the bottom border
            printf '%*s\n' "$box_width" '' | tr ' ' '='
        else
            echo "Cypher key is incorrect. Aborting retrieval."
            exit 1
        fi
    else
        echo "Account not found or decryption failed."
    fi
}

# Function to delete data
delete_data() {
    list_accounts
    read -p "Enter account ID: " id
    get_encryption_key
    record=$(sqlite3 "$db_file" "SELECT password FROM accounts WHERE id = $id;")
    account_name=$(sqlite3 "$db_file" "SELECT account_name FROM accounts WHERE id = $id;")
    if [ -n "$record" ]; then
        encrypted_password=$(echo "$record" | awk -F '|' '{print $1}')
        
        # Attempt to decrypt the password with the provided key
        if decrypted_password=$(decrypt_password "$encrypted_password" "$encryption_key" 2>/dev/null); then
            # Proceed to delete the record
            if sqlite3 "$db_file" "DELETE FROM accounts WHERE id = $id;"; then
                echo "User details for account $account_name is deleted successfully."
            else
                echo "Account not found"
            fi
        else
            echo "Cypher key is incorrect. Aborting deletion."
            exit 1
        fi
    else
        echo "Account not found or decryption failed."
    fi
}

# Function to update data
update_password() {
    list_accounts
    read -p "Enter account ID: " id
    get_encryption_key
    record=$(sqlite3 "$db_file" "SELECT account_name, email, username, mobile_number, notes, password FROM accounts WHERE id = $id;")
    if [ -n "$record" ]; then
        # Extract current values
        account_name=$(echo "$record" | awk -F '|' '{print $1}')
        email=$(echo "$record" | awk -F '|' '{print $2}')
        username=$(echo "$record" | awk -F '|' '{print $3}')
        mobile_number=$(echo "$record" | awk -F '|' '{print $4}')
        notes=$(echo "$record" | awk -F '|' '{print $5}')
        encrypted_password=$(echo "$record" | awk -F '|' '{print $6}')
        
        # Attempt to decrypt the password with the provided key
        if password=$(decrypt_password "$encrypted_password" "$encryption_key" 2>/dev/null); then
            # Display current values and prompt for new values
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

            # Use current values if user presses Enter
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

            # Update the record in the database
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
            echo "Details updated for account $new_account_name."
        else
            echo "Cypher key is incorrect. Aborting update."
            exit 1
        fi
    else
        echo "Account not found or decryption failed."
    fi
}

# Function to list all accounts
list_accounts() {
    if [ -s "$db_file" ]; then
        echo "Saved accounts:"
        sqlite3 "$db_file" "SELECT id, account_name FROM accounts;"
    else
        echo "No accounts saved"
    fi
}

# Initialize the database if not exists
initialize_db

# Check user action based on the provided parameter
case "$1" in
    add) add_password ;;
    get) get_password ;;
    delete) delete_data ;;
    update) update_password ;;
    list) list_accounts ;;
    *) echo "Invalid action. Usage: $0 {add|get|update|delete|list}" ;;
esac