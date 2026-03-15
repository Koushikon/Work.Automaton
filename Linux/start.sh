#!/bin/bash

# 1. Correct the path to the config file
CONF_FILE="./env/.sql_config"

if [ -f "$CONF_FILE" ]; then
    chmod 600 "$CONF_FILE"
    source "$CONF_FILE"
else
    echo -e "\e[31mError: $CONF_FILE not found!\e[0m"; exit 1
fi

# 2. VALIDATION: Stop if variables are empty
if [ -z "$WIN_BACKUP_PRIMARY" ] || [ -z "$LIN_BACKUP_PRIMARY" ]; then
    echo -e "\e[31mError: Variables in .sql_config are empty. Check the file content.\e[0m"
    exit 1
fi

echo "Setting up environment..."

# 3. Install dependencies
sudo apt-get update && sudo apt-get install -y cifs-utils curl

# 4. Create folders
mkdir -p "$LIN_BACKUP_FALLBACK"
sudo mkdir -p "$LIN_BACKUP_PRIMARY"
sudo chown $USER:$USER "$LIN_BACKUP_PRIMARY"

# 5. Script permissions (Using the names you provided)
chmod +x msdb-backup.sh msdb-restore.sh

# 6. Mount logic
# This converts "C:\SQLBackups" to "SQLBackups"
SHARE_NAME=$(echo "$WIN_BACKUP_PRIMARY" | sed 's/C:\\//' | sed 's/\\/\//g')

echo "Mounting Windows Share..."
read -p "Enter Windows Username: " win_user
read -s -p "Enter Windows Password: " win_pass
echo ""

# Special Note for Outlook/Microsoft Accounts:
# If your email login fails, we add "domain=MicrosoftAccount"
sudo mount -t cifs "//$SQLCMDSERVER/$SHARE_NAME" "$LIN_BACKUP_PRIMARY" \
    -o username="$win_user",password="$win_pass",iocharset=utf8,vers=3.0,domain=MicrosoftAccount

if mountpoint -q "$LIN_BACKUP_PRIMARY"; then
    echo "Mount successful!"
else
    echo "Mount failed. Check sharing permissions on Windows."
fi

echo "Setup complete."