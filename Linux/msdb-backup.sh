#!/bin/bash

# Load Configuration
[ -f "./env/.sql_config" ] && source "./env/.sql_config" || { echo "Config file not found!"; exit 1; }

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

# 1. Path Detection (Primary Samba vs Fallback)
if mountpoint -q "$LIN_BACKUP_PRIMARY" 2>/dev/null; then
    ACTIVE_LIN_PATH="$LIN_BACKUP_PRIMARY"
    ACTIVE_WIN_PATH="$WIN_BACKUP_PRIMARY"
    echo -e "${GREEN}Storage: Primary Samba Share${NC}"
else
    ACTIVE_LIN_PATH="$LIN_BACKUP_FALLBACK"
    ACTIVE_WIN_PATH=$(wslpath -w "$LIN_BACKUP_FALLBACK")
    echo -e "${YELLOW}Storage: Fallback (WSL Home)${NC}"
fi

# 2. User Input
echo -en "${CYAN}Enter Database names ('|' separated): ${NC}"
read -r db_input
IFS='|' read -ra DATABASES <<< "$db_input"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
MANIFEST_NAME="${TIMESTAMP}__manifest.csv"

# 3. Backup Loop
for DB in "${DATABASES[@]}"; do
    DB=$(echo "$DB" | xargs); [ -z "$DB" ] && continue

    FILENAME="${TIMESTAMP}__${DB}.bak"
    SQL_DEST_PATH="$ACTIVE_WIN_PATH\\$FILENAME"
    LIN_FILE_PATH="$ACTIVE_LIN_PATH/$FILENAME"

    echo -en "Backing up ${YELLOW}$DB${NC}... "

    # Execute via sqlcmd (using env vars from .sql_config)
    sqlcmd -b -Q "BACKUP DATABASE [$DB] TO DISK = N'$SQL_DEST_PATH' WITH INIT, COMPRESSION = $ENABLE_COMPRESSION, STATS = 10" > /dev/null

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}DONE${NC}"
        HASH=$(md5sum "$LIN_FILE_PATH" | awk '{print $1}')
        echo "$DB,$FILENAME,$HASH" >> "$ACTIVE_LIN_PATH/$MANIFEST_NAME"
    else
        echo -e "${RED}FAILED${NC} (Check Windows folder permissions)"
    fi
done

echo -e "\n${CYAN}Process finished. Manifest: $ACTIVE_LIN_PATH/$MANIFEST_NAME${NC}"