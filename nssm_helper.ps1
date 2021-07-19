#requires -version 2
<#
.SYNOPSIS
  Helper script to create Windows service
.DESCRIPTION
  Creates and starts Windows service
.INPUTS
  ini file
.NOTES
  Version:        0.5.0
  Author:         Rich Bocchinfuso
  Creation Date:  06/29/2021
  Purpose/Change: Helper script to create windows servcie
#>


#---------------------------------------[Initializations]---------------------------------


# Read config paramaters from config.ini file using PsIni
$CONFIG = Get-IniContent "C:\VMware_Guest_OS_Diskspace_Monitor\config.ini"

# Script Version
$RelaseVersion = $CONFIG["Environment"]["release"]


#---------------------------------------[Declarations]------------------------------------

# Environment
$nssm = (Get-Command nssm).Source
$powershell = (Get-Command powershell).Source
$arguments = '-ExecutionPolicy Bypass -NoProfile -File "{0}"' -f $scriptPath
$serviceName = $CONFIG["NSSM"]["servicename"]
$scriptPath = $CONFIG["NSSM"]["scriptpath"]

#---------------------------------------[Functions]---------------------------------------


#---------------------------------------[Execution]---------------------------------------

& $nssm install $serviceName $powershell $arguments
& $nssm status $serviceName
Start-Service $serviceName
Get-Service $serviceName

