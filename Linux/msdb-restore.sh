#!/bin/bash

# Load Configuration
[ -f "./env/.sql_config" ] && source "./env/.sql_config" || { echo "Config file not found!"; exit 1; }

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

# 1. Search for available manifests
mapfile -t MANIFESTS < <(find "$LIN_BACKUP_PRIMARY" "$LIN_BACKUP_FALLBACK" -maxdepth 1 -name "*__manifest.csv" 2>/dev/null)

if [ ${#MANIFESTS[@]} -eq 0 ]; then
    echo -e "${RED}No manifests found.${NC}"; exit 1
fi

echo -e "${CYAN}Select a manifest to restore:${NC}"
select MANIFEST_PATH in "${MANIFESTS[@]}"; do
    [ -n "$MANIFEST_PATH" ] && break
done

# 2. Set Paths based on manifest location
ACTIVE_LIN_PATH=$(dirname "$MANIFEST_PATH")
if [[ "$ACTIVE_LIN_PATH" == "$LIN_BACKUP_PRIMARY" ]]; then
    ACTIVE_WIN_PATH="$WIN_BACKUP_PRIMARY"
else
    ACTIVE_WIN_PATH=$(wslpath -w "$ACTIVE_LIN_PATH")
fi

echo -en "${YELLOW}Drop existing databases first? (y/n): ${NC}"
read -r DROP_CONFIRM

# 3. Detect Server Default Paths (Dynamic Relocation)
SQL_PATHS=$(sqlcmd -b -h -1 -Q "SET NOCOUNT ON; SELECT SERVERPROPERTY('InstanceDefaultDataPath'), SERVERPROPERTY('InstanceDefaultLogPath')" | tr -d '\r')
DEF_DATA=$(echo "$SQL_PATHS" | awk '{print $1}')
DEF_LOG=$(echo "$SQL_PATHS" | awk '{print $2}')

# 4. Process Restore Loop
while IFS=',' read -r DB_NAME BAK_FILE REQ_HASH || [ -n "$DB_NAME" ]; do
    DB_NAME=$(echo "$DB_NAME" | xargs); [ -z "$DB_NAME" ] && continue
    
    LIN_BAK="$ACTIVE_LIN_PATH/$BAK_FILE"
    WIN_BAK="$ACTIVE_WIN_PATH\\$BAK_FILE"

    echo -e "\n${CYAN}Restoring $DB_NAME...${NC}"

    # Integrity Check
    CUR_HASH=$(md5sum "$LIN_BAK" | awk '{print $1}')
    if [ "$CUR_HASH" != "$REQ_HASH" ]; then
        echo -e "${RED}Hash Mismatch! File may be corrupt. Skipping.${NC}"; continue
    fi

    # Prep: Drop existing if requested
    if [[ "${DROP_CONFIRM^^}" == "Y" ]]; then
        sqlcmd -Q "IF EXISTS(SELECT * FROM sys.databases WHERE name='$DB_NAME') BEGIN ALTER DATABASE [$DB_NAME] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$DB_NAME]; END"
    fi

    # Dynamic File Mapping (Logical to Physical)
    MOVE_SQL=""
    while read -r row; do
        L_NAME=$(echo "$row" | cut -d',' -f1); TYPE=$(echo "$row" | cut -d',' -f2)
        [[ "$TYPE" == "L" ]] && EXT="ldf" || EXT="mdf"
        [[ "$TYPE" == "L" ]] && TARGET="$DEF_LOG" || TARGET="$DEF_DATA"
        MOVE_SQL+=", MOVE N'$L_NAME' TO N'$TARGET$DB_NAME.$EXT'"
    done <<< "$(sqlcmd -b -h -1 -W -s "," -Q "SET NOCOUNT ON; RESTORE FILELISTONLY FROM DISK = N'$WIN_BAK'" | grep -v 'LogicalName')"

    # Execute Restore
    sqlcmd -b -Q "RESTORE DATABASE [$DB_NAME] FROM DISK = N'$WIN_BAK' WITH REPLACE $MOVE_SQL" > /dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}SUCCESS: Database $DB_NAME restored.${NC}"
    else
        echo -e "${RED}FAILURE: Could not restore $DB_NAME.${NC}"
    fi

done < "$MANIFEST_PATH"

echo -e "\n${CYAN}Restore process finished.${NC}"