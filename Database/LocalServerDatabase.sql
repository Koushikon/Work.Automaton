/***
 * * Database Backup Script
 * * Backup all database all at once
 */

-- Source: https://www.MSSQLTips.com
-- https://www.mssqltips.com/sqlservertip/1070/simple-script-to-backup-all-sql-server-databases/

DECLARE @name NVARCHAR(256) -- Database name  
DECLARE @path NVARCHAR(512) -- Path for backup files  
DECLARE @fileName NVARCHAR(512) -- Filename for backup  
DECLARE @fileDate NVARCHAR(40) -- Used for file name

-- Specify database backup directory
SET @path = 'D:\Program Files\Database\'

-- Specify filename format with only date
SELECT @fileDate = FORMAT(GETDATE(), 'yyyy-MM-dd')
-- Or, Specify filename format with date time
--SELECT @fileDate = FORMAT(GETDATE(), 'yyyy-MM-dd_hhmmss')



DECLARE db_cursor CURSOR READ_ONLY FOR
SELECT
	[name]
FROM master.sys.databases
WHERE
	[name] NOT IN ('master','model','msdb','tempdb')	-- Exclude these databases
	AND state = 0	-- Database is online
	AND is_in_standby = 0	-- Database is not read only for log shipping

OPEN db_cursor
FETCH NEXT FROM db_cursor INTO @name
 
WHILE @@FETCH_STATUS = 0
BEGIN
	SET @fileName = @path + @fileDate + + '_' + @name + '.bak'
   
	-- with extra option
	BACKUP DATABASE @name TO DISK = @fileName

	-- Or, With T-SQL to monitor backup progress status and Compression (Developer Edition)
	--BACKUP DATABASE @name TO DISK = @fileName WITH STATS=10, COMPRESSION

	FETCH NEXT FROM db_cursor INTO @name   
END   

CLOSE db_cursor
DEALLOCATE db_cursor