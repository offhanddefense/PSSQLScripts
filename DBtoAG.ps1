# #############################################################################
# CompanyD - SCRIPT - POWERSHELL
# NAME: DBtoAG.ps1
# 
# AUTHOR:  OffHand
# DATE:  2017/04/28
# EMAIL: OffHand
# 
# COMMENT:  This script will backup db on primary server, create and restore db
# on secondary server, then add the db to the Availability Group. It will not 
# configure or create the Availability Group.
#
# VERSION HISTORY
# 1.0 2017/04/28 Initial Version.
# 
#
# TO ADD
# -grab input from user for database, server, and AG
# -Foreach loop for mutiple databases
# -
# #############################################################################

#Variables
$PrimaryServerNumber = Read-Host 'What server number is the Database currently on?'   #"1"
$SecondaryServerNumber = Read-Host 'What server number will be the Replica for the Database?'   #"2"
$AG = Read-host 'What is the name of the Availabilty Group?' 
#$BackupFile = "\\dmgiopsql0" + $PrimaryServerNumber + "\C$\Backups"
$PrimaryServer = "dmgiopsql0$PrimaryServerNumber"
$SecondaryServer = "dmgiopsql0$SecondaryServerNumber"
$Primaryinstance = "dmgiopsql0$PrimaryServerNumber\dmgsql"
$Secondaryinstance = "dmgiopsql0$SecondaryServerNumber\dmgsql"
$mdfpath = "C:\ClusterStorage\SQLData\INSTANCE"
$ldfpath = "C:\ClusterStorage\SQLLogs\INSTANCE"

$DBname = Read-Host 'What is the name of the Database?'  #   "DATAvase"
$LDFname = $DBname + "_log"
$BackupFile = "\\dmgiopsql0" + $PrimaryServerNumber + "\C$\BACKUP\" + $DBname + ".bak"
$BackupFULLName = $DBname + "-Full Database Backup"
$SecondaryDBmdf = $mdfpath + $SecondaryServerNumber + "\" + $DBname + ".mdf"
$SecondaryDBldf = $ldfpath + $SecondaryServerNumber + "\" + $LDFname + ".ldf"

#Create database on second server
invoke-sqlcmd -ServerInstance $Secondaryinstance -query "
CREATE DATABASE $($DBname)
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'$($DBname)', FILENAME = N'$($SecondaryDBmdf)' , SIZE = 4096KB , FILEGROWTH = 1024KB )
 LOG ON 
( NAME = N'$($LDFname)', FILENAME = N'$($SecondaryDBldf)' , SIZE = 1024KB , FILEGROWTH = 10%)
GO
ALTER DATABASE $($DBname) SET COMPATIBILITY_LEVEL = 120
GO
ALTER DATABASE $($DBname) SET ANSI_NULL_DEFAULT OFF 
GO
ALTER DATABASE $($DBname) SET ANSI_NULLS OFF 
GO
ALTER DATABASE $($DBname) SET ANSI_PADDING OFF 
GO
ALTER DATABASE $($DBname) SET ANSI_WARNINGS OFF 
GO
ALTER DATABASE $($DBname) SET ARITHABORT OFF 
GO
ALTER DATABASE $($DBname) SET AUTO_CLOSE OFF 
GO
ALTER DATABASE $($DBname) SET AUTO_SHRINK OFF 
GO
ALTER DATABASE $($DBname) SET AUTO_CREATE_STATISTICS ON(INCREMENTAL = OFF)
GO
ALTER DATABASE $($DBname) SET AUTO_UPDATE_STATISTICS ON 
GO
ALTER DATABASE $($DBname) SET CURSOR_CLOSE_ON_COMMIT OFF 
GO
ALTER DATABASE $($DBname) SET CURSOR_DEFAULT  GLOBAL 
GO
ALTER DATABASE $($DBname) SET CONCAT_NULL_YIELDS_NULL OFF 
GO
ALTER DATABASE $($DBname) SET NUMERIC_ROUNDABORT OFF 
GO
ALTER DATABASE $($DBname) SET QUOTED_IDENTIFIER OFF 
GO
ALTER DATABASE $($DBname) SET RECURSIVE_TRIGGERS OFF 
GO
ALTER DATABASE $($DBname) SET  DISABLE_BROKER 
GO
ALTER DATABASE $($DBname) SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO
ALTER DATABASE $($DBname) SET DATE_CORRELATION_OPTIMIZATION OFF 
GO
ALTER DATABASE $($DBname) SET PARAMETERIZATION SIMPLE 
GO
ALTER DATABASE $($DBname) SET READ_COMMITTED_SNAPSHOT OFF 
GO
ALTER DATABASE $($DBname) SET  READ_WRITE 
GO
ALTER DATABASE $($DBname) SET RECOVERY FULL 
GO
ALTER DATABASE $($DBname) SET  MULTI_USER 
GO
ALTER DATABASE $($DBname) SET PAGE_VERIFY CHECKSUM  
GO
ALTER DATABASE $($DBname) SET TARGET_RECOVERY_TIME = 0 SECONDS 
GO
ALTER DATABASE $($DBname) SET DELAYED_DURABILITY = DISABLED 
GO
USE $($DBname)
GO
IF NOT EXISTS (SELECT name FROM sys.filegroups WHERE is_default=1 AND name = N'PRIMARY') ALTER DATABASE $($DBname) MODIFY FILEGROUP [PRIMARY] DEFAULT
GO
"

#Backup and verify datebase on primary server
Invoke-Sqlcmd -serverInstance $Primaryinstance -query "
BACKUP DATABASE $($DBname) TO  DISK = N'$($BackupFile)' WITH NOFORMAT, INIT,  NAME = N'$($BackupFULLName)', SKIP, NOREWIND, NOUNLOAD, COMPRESSION,  STATS = 10
GO
declare @backupSetId as int
select @backupSetId = position from msdb..backupset where database_name=N'$($DBname)' and backup_set_id=(select max(backup_set_id) from msdb..backupset where database_name=N'$($DBname)' )
if @backupSetId is null begin raiserror(N'Verify failed. Backup information for database ''$($DBname)'' not found.', 16, 1) end
RESTORE VERIFYONLY FROM  DISK = N'$($BackupFile)' WITH  FILE = @backupSetId,  NOUNLOAD,  NOREWIND
GO
"


#Backup Transactionlog on primary server

Invoke-Sqlcmd -serverInstance $Primaryinstance -query "

BACKUP LOG $($DBname) TO  DISK = N'$($BackupFile)' WITH NOFORMAT, NOINIT,  NAME = N'$($BackupFULLName)', SKIP, NOREWIND, NOUNLOAD, COMPRESSION,  STATS = 10
GO
declare @backupSetId as int
select @backupSetId = position from msdb..backupset where database_name=N'$($DBname)' and backup_set_id=(select max(backup_set_id) from msdb..backupset where database_name=N'$($DBname)' )
if @backupSetId is null begin raiserror(N'Verify failed. Backup information for database ''$($DBname)'' not found.', 16, 1) end
RESTORE VERIFYONLY FROM  DISK = N'$($BackupFile)' WITH  FILE = @backupSetId,  NOUNLOAD,  NOREWIND
GO
"


# Restore database on secondary server


Invoke-Sqlcmd -serverInstance $Secondaryinstance -query "
USE [master]
RESTORE DATABASE $($DBname) FROM  DISK = N'$($BackupFile)' WITH  FILE = 1,  MOVE N'$($DBname)' TO N'$($SecondaryDBmdf)',  MOVE N'$($LDFname)' TO N'$($SecondaryDBldf)',  NORECOVERY,  NOUNLOAD,  REPLACE,  STATS = 5
RESTORE LOG $($DBname) FROM  DISK = N'$($BackupFile)' WITH  FILE = 2,  NORECOVERY,  NOUNLOAD,  STATS = 5

GO

"


# Add database to Availabilty group

invoke-sqlcmd -ServerInstance $Primaryinstance -query "
USE [master]

GO

ALTER AVAILABILITY GROUP $($AG)
ADD DATABASE $($DBname);

GO
"

invoke-sqlcmd -ServerInstance $Secondaryinstance -query "

-- Wait for the replica to start communicating
begin try
declare @conn bit
declare @count int
declare @replica_id uniqueidentifier 
declare @group_id uniqueidentifier
set @conn = 0
set @count = 30 -- wait for 5 minutes 

if (serverproperty('IsHadrEnabled') = 1)
	and (isnull((select member_state from master.sys.dm_hadr_cluster_members where upper(member_name COLLATE Latin1_General_CI_AS) = upper(cast(serverproperty('ComputerNamePhysicalNetBIOS') as nvarchar(256)) COLLATE Latin1_General_CI_AS)), 0) <> 0)
	and (isnull((select state from master.sys.database_mirroring_endpoints), 1) = 0)
begin
    select @group_id = ags.group_id from master.sys.availability_groups as ags where name = N'$($AG)'
	select @replica_id = replicas.replica_id from master.sys.availability_replicas as replicas where upper(replicas.replica_server_name COLLATE Latin1_General_CI_AS) = upper(@@SERVERNAME COLLATE Latin1_General_CI_AS) and group_id = @group_id
	while @conn <> 1 and @count > 0
	begin
		set @conn = isnull((select connected_state from master.sys.dm_hadr_availability_replica_states as states where states.replica_id = @replica_id), 1)
		if @conn = 1
		begin
			-- exit loop when the replica is connected, or if the query cannot find the replica status
			break
		end
		waitfor delay '00:00:10'
		set @count = @count - 1
	end
end
end try
begin catch
	-- If the wait loop fails, do not stop execution of the alter database statement
end catch
ALTER DATABASE $($DBname) SET HADR AVAILABILITY GROUP = $($AG);

GO


GO

"