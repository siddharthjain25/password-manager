# Password Manager
This is a simple and secure password manager script written in Bash. It allows you to store, retrieve, update, delete, and list passwords along with related account information, using an SQLite database for persistent storage. The passwords are securely encrypted using OpenSSL's AES-256-CBC encryption.

# Features
- `Add Account`: Save account details (account name, email, username, mobile number, notes, and password).
- `Get Account`: Retrieve and decrypt stored account details by account ID.
- `Update Account`: Modify existing account details, with the option to retain existing information.
- `Delete Account`: Remove stored account details by account ID.
- `List Accounts`: View a list of saved accounts along with their unique IDs.
- `Encryption`: Passwords are encrypted using AES-256-CBC for security.
- `Master Key`: An encryption key is prompted for every operation, ensuring that data cannot be accessed without the correct key.

# Requirements
- `Bash`: This script requires a Unix-like environment with Bash installed.
- `SQLite`: The script uses SQLite as the database for storing account details.
- `OpenSSL`: OpenSSL is used for encrypting and decrypting passwords.

# For single-line installation
    sudo apt install sqlite3 openssl
    curl -L https://raw.githubusercontent.com/siddharthjain25/password-manager/main/install.sh | sudo bash

# Setup
Download and Install Dependencies: Ensure that SQLite and OpenSSL are installed on your system. You can install them using your package manager:

## On Ubuntu or Debian-based systems
    sudo apt update
    sudo apt install sqlite3 openssl

## On Fedora-based systems
    sudo dnf install sqlite openssl
    
## Clone the Repository: Download the script to your system.
    git clone https://github.com/siddharthjain25/password-manager.git
    cd password-manager``

## Make the Script Executable:
    chmod +x sanji_password_manager.sh

Initialize the Database: The script will automatically create the SQLite database (data.db) in the specified directory when it runs for the first time.

# Usage
You can perform various operations using this script by providing the corresponding action as a parameter.

General Syntax

    ./sanji_password_manager.sh {add|get|update|delete|list}
    # Replace {add|get|update|delete|list} with the action you want to perform.

# Examples
### Add a New Account
To add a new account with its associated details:

    ./sanji_password_manager.sh add

You will be prompted to enter the account details (account name, email, username, mobile number, notes, and password). After entering the details, you will also need to provide an encryption key to encrypt the password.

### Retrieve an Account
To retrieve and decrypt an account's details by its ID:

    ./sanji_password_manager.sh get

You will be shown a list of account IDs. After entering the account ID, you will be prompted for the encryption key to decrypt and display the details.

### Update an Account
To update an existing account's details:

    ./sanji_password_manager.sh update

You will be shown a list of account IDs. After entering the account ID, the script will display the current details for that account, and you will be prompted to update each field. You can press Enter to keep the current value.

### Delete an Account
To delete an account by its ID:

    ./sanji_password_manager.sh delete

You will be shown a list of account IDs. After entering the account ID, the account will be deleted from the database.

### List All Accounts
To view a list of all saved accounts:

    ./sanji_password_manager.sh list

This will display a list of all account IDs and their associated account names.

### Security Considerations
- `Encryption`: The script uses AES-256-CBC encryption for passwords. The encryption key is prompted for every operation, ensuring that sensitive data is never stored in plain text.
- `Master Key`: The encryption key is not saved in the script or the database, providing an additional layer of security.
- `Database Storage`: All account details, except for the encrypted password, are stored in plain text in the SQLite database. Ensure that the database file (data.db) is stored securely and with appropriate permissions.

# Database save location
    $Home/.config/sanji-pm-data.db

# Database Structure
The SQLite database consists of a single table accounts with the following schema:


    CREATE TABLE IF NOT EXISTS accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_name TEXT NOT NULL,
        email TEXT,
        username TEXT,
        mobile_number TEXT,
        notes TEXT,
        password TEXT NOT NULL
    );

# Error Handling
- The script checks for invalid input (e.g., invalid account IDs) and provides appropriate error messages.
- If the encryption key is incorrect, decryption will fail, and the password will not be displayed.

# Contribution
Feel free to fork this repository and submit pull requests to improve the functionality or security of the script.

# License
This project is licensed under the MIT License.
