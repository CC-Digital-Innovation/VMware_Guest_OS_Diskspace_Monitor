#requires -version 5
<#
.SYNOPSIS
  Script to install requirements
.DESCRIPTION
  Installs requirements
.INPUTS
  None
.NOTES
  Version:        0.6.0
  Author:         Rich Bocchinfuso
  Creation Date:  06/29/2021
  Purpose/Change: Initial script development to monitor and alert on VM guest volume free space
#>

# Start-Process Powershell -Verb RunAs
# Set-ExecutionPolicy -Confirm:$false Unrestricted -Force
# Get-ExecutionPolicy
# Install-Module -Confirm:$false -Name PsIni

#---------------------------------------[Initializations]---------------------------------

# Install PSIni Module
Install-Module -Confirm:$false -Name PsIni

# Read config paramaters from config.ini file using PsIni
$CONFIG = Get-IniContent "$PSScriptRoot\config.ini"

# Script Version
$RelaseVersion = $CONFIG["Environment"]["release"]


#---------------------------------------[Declarations]------------------------------------

$modules = $CONFIG["Powershell"]["modules"]

#---------------------------------------[Functions]---------------------------------------

function InstallModules {
  $ModuleArray = $modules.Split(",")
  $ModuleArray
  foreach ($psm in $ModuleArray) {
    if (Get-Module -ListAvailable -Name $psm) {
      Write-Host ($psm + " is already installed")
    }
    else {
      try {
        Install-Module -Name $psm -AllowClobber -Confirm:$False -Force
      }
      catch [Exception] {
        $_.message
        exit
      }
    }
  }
}


#---------------------------------------[Execution]---------------------------------------


# Check to see if you are running as Administator, if not elevate privledge
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {  
  $arguments = "& '" + $myinvocation.mycommand.definition + "'"
  Start-Process powershell -Verb runAs -ArgumentList $arguments
  Break
}


Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted

InstallModules

# Install Chocolaty and NSSM
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
& choco install nssm --confirm

Set-PowerCLIConfiguration -Confirm:$false -ParticipateInCEIP:$false
Set-PowerCLIConfiguration -Confirm:$false -InvalidCertificateAction Ignore

