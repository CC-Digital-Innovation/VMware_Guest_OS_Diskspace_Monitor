#requires -version 2
<#
.SYNOPSIS
  Script to monitor VM guest volume space and alert on low space
.DESCRIPTION
  Script to enumerate VM guest disks volumes to check if a volume has fallen below a defined free space threshold, and trigger an Opsgenie alert if the volume is below the defined threshold
.INPUTS
  ini file
.NOTES
  Version:        0.5.0
  Author:         Rich Bocchinfuso
  Creation Date:  06/29/2021
  Purpose/Change: Initial script development to monitor and alert on VM guest volume free space
#>


#---------------------------------------[Initializations]---------------------------------

# Debug logging
Start-Transcript -path C:\VMware_Guest_OS_Diskspace_Monitor\output.log -append

# Read config paramaters from config.ini file using PsIni
$CONFIG = Get-IniContent "C:\VMware_Guest_OS_Diskspace_Monitor\config.ini"

# Script Version
$RelaseVersion = $CONFIG["Environment"]["release"]


#---------------------------------------[Declarations]------------------------------------

# Environment
$envname = $CONFIG["Environment"]["envname"]

# Cycle Time
$cycletime = $CONFIG["Environment"]["cycletime"]

# vCenter settings
$vcserver = $CONFIG["VMware"]["vcserver"]
$vcuser = $CONFIG["VMware"]["vcuser"]
$vcpassword = $CONFIG["VMware"]["vcpassword"]

# Disk PercentFreeSpace threshold
$PercentageFreeSpaceThreshold = $CONFIG["Thresholds"]["PercentFreeSpace"]

# Opsgenie
$OpsgenieAPI = $CONFIG["Opsgenie"]["api"]
$OpsgenieURI = $CONFIG["Opsgenie"]["URI"]
$OpsgenieResponders = $CONFIG["Opsgenie"]["responders"]
$OpsgenieTags = $CONFIG["Opsgenie"]["tags"]
$OpsgeniePriority = $CONFIG["Opsgenie"]["priority"]

# Logging
# Local Console Logging
$VerbosePreference = $CONFIG["Logging"]["VerbosePreference"]
$DebugPreference = $CONFIG["Logging"]["DebugPreference"]
$ErrorActionPreference = $CONFIG["Logging"]["ErrorActionPreference"]
$WarningPreference = $CONFIG["Logging"]["WarningPreference"]
$InformationPreference = $CONFIG["Logging"]["InformationPreference"]
# Syslog
$SyslogServer = $CONFIG["Logging"]["SyslogServer"]
$SyslogPort = $CONFIG["Logging"]["SyslogPort"]


#---------------------------------------[Functions]---------------------------------------


Function Opsgenie_Alert($message,$alias) {

  # Create responders payload
  $ResponderItems = $OpsgenieResponders.Split(",")
  # Declare an empty array
  $responders = @()
  # Add items to responders array
  foreach ($responder in $ResponderItems) {
    $responders += @{
        name = $responder
        type = "team"
      }
  }

  # Create tag payload
  $tagItems = $OpsgenieTags.Split(",")
  # Declare an empty array
  $tags = @()
  # Add items to tags array
  foreach ($tag in $tagItems) {
    $tags += @(
      $tag
    )
  }

  $body = @{
      message = $message
      alias = $alias
      responders = $responders
      tags = $tags
      priority = $OpsgeniePriority
  } | ConvertTo-Json

  $invokeRestMethodParams = @{
      'Headers'     = @{
          "Authorization" = "GenieKey $OpsgenieAPI"
      }
      'Uri'         = $OpsgenieURI
      'ContentType' = 'application/json'
      'Body'        = $body
      'Method'      = 'Post'
  }

  $request = Invoke-RestMethod @invokeRestMethodParams
  Write-Debug ("Opsgenie request response: " + $request)
} #end function Opsgenie


Function Syslog($envname,$source,$message,$sev) {
  # Function call:  Syslog [Envrionment Name] [Host | VM | App Name] [Message] [Serverity]
  # Serverity options = Emergency | Alert | Critical | Error | Warning | Notice | Informational | Debug
  Send-Syslogmessage -Server $SyslogServer -Port $SyslogPort -Message $message -Severity $sev -Facility user -Hostname $envname -ApplicationName $source -Transport UDP
}

#---------------------------------------[Execution]---------------------------------------


Write-Information "Connecting to vCenter..."
$connection = Connect-VIServer -Server $vcserver -User $vcuser -Password $vcpassword

if ($connection.IsConnected -eq 'True'){$connection}
else {
	Write-Error "*** Exitting - connection to the server does NOT exist ***"
	exit
}

while($true) {
  # Get-VM -Name vcsa-vlab | ForEach-Object {
  Get-VM | ForEach-Object {

    $VM = $_
    $_.Guest.Disks | ForEach-Object {
      $output = "" | Select-Object -Property VM,Path,Capacity_GB,UsedSpace_GB,FreeSpace_GB,PercentageFreeSpace
      $output.VM = $VM.Name
      $output.Path = $_.Path
      $output.Capacity_GB = ([math]::Round($_.Capacity / 1GB,2))
      $output.UsedSpace_GB = ([math]::Round(($_.Capacity - $_.FreeSpace) / 1GB,2))
      $output.FreeSpace_GB = ([math]::Round($_.FreeSpace / 1GB,2))
      if ($_.Capacity) {$output.PercentageFreeSpace = ([math]::Round(100*($_.FreeSpace/$_.Capacity)))}
      # $output
      if ($output.PercentageFreeSpace) {
          if ($output.PercentageFreeSpace -lt $PercentageFreeSpaceThreshold) {
              $message = ("[DISK SPACE ALERT] [$envname] " + $output.VM + " device " + $output.Path + " has " + $output.PercentageFreeSpace + "% free space, which is below the defined threshold of " + $PercentageFreeSpaceThreshold + "%.")
              $alias = ($envname + "_" + $output.VM + "_" + $output.Path)
              Write-Warning ("ALERT: " + $message)
              Write-Warning ("Alert Alias: " + $alias)
              Syslog $envname $output.VM $message Alert
              # Opsgenie_Alert $message $alias
              $output | Format-Table VM,Path,Capacity_GB,UsedSpace_GB,FreeSpace_GB,PercentageFreeSpace
          }
      }
    }
  }
  Start-Sleep $cycletime
}

Disconnect-VIServer -Server $vcserver -confirm:$false

Stop-Transcript