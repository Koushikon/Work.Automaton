# SQL Server Backup & Restore Guide (WSL/Bash)

## Overview
This system consists of four files:
1.  **`env\.sql_config`**: The configuration file containing your credentials and paths.
2.  **`start.sh`**: Prepares folders, permissions, and network mounts.
3.  **`msdb-backup.sh`**: Performs backups to a network share or local fallback.
4.  **`msdb-restore.sh`**: Restores databases using manifest files and integrity checks.


## Step 1: Create the Configuration File
You must create a hidden file in your Linux home directory to store your settings. This prevents passwords from being hardcoded into the scripts.

1.  Open your WSL terminal.
2.  Create the file:
    ```bash
    nano ~/env/.sql_config
    ```
3.  Paste the following template and **edit the values** to match your environment:
    ```bash
    # ~/.sql_config
    # SQL Connection Settings
    export SQLCMDSERVER="<db_server>"
    export SQLCMDUSER="<username>"
    export SQLCMDPASSWORD='<password>'

    # PATHS
    # 1. How the Windows SQL Service sees the folder:
    export WIN_BACKUP_PATH="<win_path>"

    # 2. How your Linux machine sees that same folder (via Samba mount):
    export LIN_BACKUP_PATH="<linux_path>"

    # Options
    export ENABLE_COMPRESSION="ON"
    ```
4.  Save and exit (`Ctrl+O`, `Enter`, `Ctrl+X`).


## Step 2: Prepare the Windows Side
Before running the setup, ensure the folder on Windows is shared:
1.  Create `C:\SQLBackups` on Windows.
2.  **Right-click** the folder -> **Properties** -> **Sharing** -> **Advanced Sharing**.
3.  Check **Share this folder**.
4.  Click **Permissions** and ensure your Windows User has **Full Control**.
5.  **Security Tab:** Also ensure that the Windows user `NT SERVICE\MSSQLSERVER` (or `Everyone` for testing) has **Full Control**.


## Step 3: Run the Initial Setup
The `start.sh` script installs system tools, creates directories, and mounts your Windows folder to Linux.

1.  Place `start.sh`, `msdb-backup.sh`, and `msdb-restore.sh` in the same folder.
2.  Give the setup script permission to run:
    ```bash
    chmod +x start.sh
    ```
3.  Execute the setup:
    ```bash
    ./start.sh
    ```
4.  **What to expect:**
    *   It will ask for your **Linux sudo password** to install tools.
    *   It will ask for your **Windows Username and Password** to mount the network drive.
    *   It will automatically make your backup and restore scripts executable.


## Step 4: Running a Backup
Use this script whenever you want to back up one or more databases.

1.  Run the script:
    ```bash
    ./msdb-backup.sh
    ```
2.  **Input:** When prompted, enter database names separated by a pipe (`|`).
    *   Example: `Northwind|CustomerDB|Sales_Data`
3.  **Process:**
    *   The script checks if the Samba share is connected.
    *   If not, it automatically switches to the Fallback folder.
    *   It generates a `.bak` file and a unique `manifest.csv` for the session.
    *   It calculates an MD5 hash for integrity.


## Step 5: Running a Restore
Use this script to restore databases from a previous backup session.

1.  Run the script:
    ```bash
    ./msdb-restore.sh
    ```
2.  **Selection:** 
    *   The script will list all available manifest files found in both Primary and Fallback locations.
    *   Type the number of the manifest you wish to use.
3.  **Options:** It will ask if you want to drop existing databases first (`y/n`).
4.  **Process:**
    *   It verifies the MD5 hash of every file before restoring.
    *   It dynamically maps the database files (`.mdf`/`.ldf`) to the correct default folders on the destination SQL Server.


## Troubleshooting

| Issue | Solution |
| :--- | :--- |
| **"Permission Denied" in SQL** | Ensure the Windows folder `C:\SQLBackups` has "Full Control" permissions for the `NT SERVICE\MSSQLSERVER` user. |
| **"Mount Failed"** | Ensure the folder is shared on Windows and that you used your Windows Windows login (not SQL login) in `setup.sh`. |
| **"sqlcmd not found"** | The scripts attempt to auto-install this. If it fails, run `sudo apt install mssql-tools`. |
| **Password with special characters** | Always wrap your password in single quotes (`'`) inside the `.sql_config` file to prevent Bash from misinterpreting symbols like `$`. |

[Back Home](./../Readme.md)