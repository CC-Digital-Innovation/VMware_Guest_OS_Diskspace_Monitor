#requires -version 5
<#
.SYNOPSIS
  Script to monitor VM guest volume space and alert on low space
.DESCRIPTION
  Script to enumerate VM guest disks volumes to check if a volume has fallen below a defined free space threshold, and trigger an Opsgenie alert if the volume is below the defined threshold
.INPUTS
  ini file
.NOTES
  Version:        0.6.0
  Author:         Rich Bocchinfuso
  Creation Date:  06/29/2021
  Purpose/Change: Initial script development to monitor and alert on VM guest volume free space
#>


#---------------------------------------[Initializations]---------------------------------

# Start logging for debugging
Start-Transcript -path "$PSScriptRoot\output.log" -append

# Import Modules
Import-Module PSWriteHTML -Force

# Read config paramaters from config.ini file using PsIni
$CONFIG = Get-IniContent "$PSScriptRoot\config.ini"

# Script Version
$RelaseVersion = $CONFIG["Environment"]["release"]


#---------------------------------------[Declarations]------------------------------------

# Environment
$envname = $CONFIG["Environment"]["envname"]

# Cycle Time
$cycletime = $CONFIG["Environment"]["cycletime"]

# vCenter settings
$vcservers = $CONFIG["VMware"]["vcservers"]
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

# Email
$SmtpServer = $CONFIG["Email"]["SmtpServer"]
$SmtpUsername = $CONFIG["Email"]["Username"]
$SmtpPassword = $CONFIG["Email"]["Password"]
$EmailFrom = $CONFIG["Email"]["From"]
$EmailTo = $CONFIG["Email"]["To"]
$EmailCC = $CONFIG["Email"]["CC"]
$EmailBCC = $CONFIG["Email"]["BCC"]
$EmailReplyTo = $CONFIG["Email"]["ReplyTo"]
$EmailSubject = $CONFIG["Email"]["Subject"]
$EmailPriority = $CONFIG["Email"]["Priority"]


#---------------------------------------[Functions]---------------------------------------

function Opsgenie_Alert($message, $alias) {

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
    message    = $message
    alias      = $alias
    responders = $responders
    tags       = $tags
    priority   = $OpsgeniePriority
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


function Syslog($envname, $source, $message, $sev) {
  # Function call:  Syslog [Envrionment Name] [Host | VM | App Name] [Message] [Serverity]
  # Serverity options = Emergency | Alert | Critical | Error | Warning | Notice | Informational | Debug
  Send-Syslogmessage -Server $SyslogServer -Port $SyslogPort -Message $message -Severity $sev -Facility user -Hostname $envname -ApplicationName $source -Transport UDP
}

function napTime($seconds) {
  $doneDT = (Get-Date).AddSeconds($seconds)
  while($doneDT -gt (Get-Date)) {
      $secondsLeft = $doneDT.Subtract((Get-Date)).TotalSeconds
      $percent = ($seconds - $secondsLeft) / $seconds * 100
      Write-Progress -Activity "Sleeping for $seconds seconds" -Status "Sleep Progress..." -SecondsRemaining $secondsLeft -PercentComplete $percent
      [System.Threading.Thread]::Sleep(500)
  }
  Write-Progress -Activity "Sleeping for $seconds seconds" -Status "Sleep Progress..." -SecondsRemaining 0 -Completed
}

function sendReport ($digest) {
  Email -Supress $false -AttachSelf -AttachSelfName $EmailSubject {
    EmailHeader {
      EmailFrom -Address $EmailFrom
      EmailReplyTo -Address $EmailReplyTo
      EmailTo -Addresses $EmailTo
      EmailCC -Addresses $EmailCC
      EmailBCC -Addresses $EmailBCC
      EmailServer -Server $SmtpServer -UserName $SmtpUsername -Password $SmtpPassword -SSL
      EmailOptions -Priority $EmailPriority
      EmailSubject -Subject $EmailSubject
    }
    EmailBody {
      EmailTextBox -FontFamily 'Calibri' -Size 15 {
        "Hello, here is your VMware Guest OS disk space usage report."
        "Only VMs with disks that have fallen below the defined disk space threshold of $PercentageFreeSpaceThreshold% are shown in this report."
        ""
        "A table desplaying VMs with disks below the $PercentageFreeSpaceThreshold% free space is embeded and attached to this email."
      }
      EmailTextBox -FontFamily 'Calibri' -Size 15 -FontStyle italic -FontWeight bold -Color Red {
        "Note: Downloading the attachment and opening it in your browser will reveal enhanced reporting features."
      }
      EmailText -LineBreak
      EmailTextBox -FontFamily 'Calibri' -Size 15 -TextDecoration underline -Color Black -Alignment center -FontWeight bold {
        $EmailSubject
      }
      EmailTable -Table $digest
    }
  }
}

function vCenter_Connect ($vc) {
  Write-Information "Connecting to vCenter..."
  $connection = Connect-VIServer -Server $vc -User $vcuser -Password $vcpassword

  if ($connection.IsConnected -eq 'True') { $connection }
  else {
    Write-Error "*** Exitting - connection to the server does NOT exist ***"
    exit
  }
}

function VM_diskspace {
  # Get-VM -Name vcsa-vlab | ForEach-Object {
  Get-VM | ForEach-Object {

    $VM = $_
    $_.Guest.Disks | ForEach-Object {
      $output = "" | Select-Object -Property VM, Path, Capacity_GB, UsedSpace_GB, FreeSpace_GB, PercentageFreeSpace
      $output.VM = $VM.Name
      $output.Path = $_.Path
      $output.Capacity_GB = ([math]::Round($_.Capacity / 1GB, 2))
      $output.UsedSpace_GB = ([math]::Round(($_.Capacity - $_.FreeSpace) / 1GB, 2))
      $output.FreeSpace_GB = ([math]::Round($_.FreeSpace / 1GB, 2))
      if ($_.Capacity) { $output.PercentageFreeSpace = ([math]::Round(100 * ($_.FreeSpace / $_.Capacity))) }
      # $output
      if ($output.PercentageFreeSpace) {
        if ($output.PercentageFreeSpace -lt $PercentageFreeSpaceThreshold) {
          $message = ("[DISK SPACE ALERT] [$envname] " + $output.VM + " device " + $output.Path + " has " + $output.PercentageFreeSpace + "% free space, which is below the defined threshold of " + $PercentageFreeSpaceThreshold + "%.")
          $alias = ($envname + "_" + $output.VM + "_" + $output.Path)
          Write-Warning ("ALERT: " + $message)
          Write-Warning ("Alert Alias: " + $alias)
          Syslog $envname $output.VM $message Alert
          # Opsgenie_Alert $message $alias
          $output | Format-Table VM, Path, Capacity_GB, UsedSpace_GB, FreeSpace_GB, PercentageFreeSpace
          $digest = @()
          # Add items to tags array
          $digest += @(
            $output
          )
          sendReport $digest
        }
      }
    }
  }
}


#---------------------------------------[Execution]---------------------------------------

while ($true) {
  # Read and split vCenter servers from config.ini
  $vcItems = $vcservers.Split(",")
  # Loop through vCenter servers
  foreach ($vc in $vcItems) {
    vCenter_Connect $vc
    VM_diskspace
    Disconnect-VIServer -Server $vc -confirm:$false
  }
  napTime $cycletime
}

# For debugging
Stop-Transcript