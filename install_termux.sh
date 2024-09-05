#!/bin/bash

# Set the download URL for the binary file
BINARY_URL="https://github.com/siddharthjain25/password-manager/releases/download/v1.0/sanjipmt"
BINARY_NAME="sanjipmt"

# Set the target installation directory
INSTALL_DIR="/data/data/com.termux/files/usr/bin"

# Ensure the script is run with root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or use sudo."
  exit 1
fi

# Download the binary file
echo "Downloading $BINARY_NAME..."
curl -L -o "$BINARY_NAME" "$BINARY_URL"

# Check if the download was successful
if [ ! -f "$BINARY_NAME" ]; then
  echo "Error: Failed to download $BINARY_NAME."
  exit 1
fi

# Move the binary to the /usr/bin directory
echo "Installing $BINARY_NAME to $INSTALL_DIR..."
mv "$BINARY_NAME" "$INSTALL_DIR/"

# Ensure the binary is executable
chmod +x "$INSTALL_DIR/$BINARY_NAME"

# Verify the installation
if [ -f "$INSTALL_DIR/$BINARY_NAME" ]; then
  echo "$BINARY_NAME successfully installed in $INSTALL_DIR."
else
  echo "Error: Failed to install $BINARY_NAME."
  exit 1
fi

echo "Installation complete. You can now run the tool using '$BINARY_NAME'."
