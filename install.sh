#!/bin/bash

echo "Installing LogSentry CLI..."

INSTALL_PATH="/usr/local/bin/logsentry"

# Copy script
sudo cp logsentry "$INSTALL_PATH"

# Make executable
sudo chmod +x "$INSTALL_PATH"

echo "LogSentry installed successfully!"