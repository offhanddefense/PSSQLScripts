# #############################################################################
# CompanyD - SCRIPT - POWERSHELL
# NAME: AttachDatabases.ps1
# 
# AUTHOR:  OffHand
# DATE:  2017/04/28
# EMAIL: OffHand
# 
# COMMENT:  Query the default database store location for a string and attach 
#           the database and log from that location. Great for restore.
#
# VERSION HISTORY
# 1.0 2017/04/28 Initial Version.
# 
#
# TO ADD
# -ifthen statement for user input for a single database
# -Check to see if the db is already in SQL
# -Report at the end of successfully added databases
# #############################################################################


$servernumber = "1" #change based on server number
$databasewildcard = "corepoint*" #change based on Database Group
#$dbname = read-host "What is the name of the database?"

$mdfpath = "C:\ClusterStorage\SQLData\INSTANCE$servernumber" 
$ldfpath = "C:\ClusterStorage\SQLLogs\INSTANCE$servernumber"
$instance = "dmgiopsql0$servernumber\dmgsql"
$strcount = $mdfpath.Length + 1
$dbs = get-item $mdfpath\* | ? {$_.name -like $databasewildcard}



foreach ($db in $dbs) {
$dbname = $db -replace "....$"
$dbname = $dbname.Substring($strcount)
$dbname

$dbmdf = $mdfpath + '\' + $dbname + '.mdf'
$dbldf = $ldfpath + '\' + $dbname + '_log.ldf'

invoke-sqlcmd -ServerInstance $instance -query "
CREATE DATABASE $($dbname) ON 
( FILENAME = N'$($dbmdf)' ),
( FILENAME = N'$($dbldf)' )
 FOR ATTACH
 "

 }

