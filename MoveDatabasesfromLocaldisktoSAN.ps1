# #############################################################################
# CompanyD - SCRIPT - POWERSHELL
# NAME: MoveDatabasesfromLocaldisktoSAN.ps1
# 
# AUTHOR:  OffHand
# DATE:  2017/03/08
# EMAIL: OffHand
# 
# COMMENT:  This script will correct the bandaid solution used when the SAN disk
#           was unstable. Databases were moved to local flash on each server, but
#           this script will move them back to the SAN. Data will be imported from csv
#
# VERSION HISTORY
# 1.0 2011.05.25 Initial Version.
# 
#
# TO ADD
# -Add a Function to ...
# -Fix the...
# #############################################################################


$Databases = import-csv c:\temp\databasestomove.csv
$LocalDBLocation =
$LocalLogLocation =  
$ClusterDBLocation = C:\clusterstorage\
$ClusterLogLocation = 
$DBBackupLocation = 
$LogBackupLocation = 
$SQLServerName = '123'
$SQLInstanceName = 'dmgsql'


foreach ($database in $Databases) {
  $DatabaseBackupName = "$DBBackupLocation" + "\" + "$database" + ".dbbak"
  $DatabaseBackupNameLog = "$LogBackupLocation" + "\" + "$database" + ".lbak"
  #Need to disconnect all users and/or disable the DB

  Invoke-SQLcmd -ServerInstance "$SQLServerName\$SQLInstanceName" -Query "ALTER DATABASE $database SET OFFLINE WITH ROLLBACK AFTER 120 SECONDS"
  Backup-SqlDatabase -ServerInstance "$SQLServerName\$SQLInstanceName" -Database $database -BackupFile $DBBackupLocation -BackupAction Database
  Backup-SqlDatabase -ServerInstance "$SQLServerName\$SQLInstanceName" -Database $database -BackupFile $LogBackupLocation -BackupAction Log
   #remove from AG
   #dismount from SQL
   #copy DB and Log from old location to new
  #mount in SQL 
  #mount in AG
   
  
  
  
  
  Invoke-SQLcmd -ServerInstance "$SQLServerName\$SQLInstanceName" -Query "ALTER DATABASE $database SET ONLINE" 
  
  }