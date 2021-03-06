﻿<##################################################################################################

    Description
    ===========

	- This script does the following - 
		- configures hyper-v
		- configures minikube

	- This script generates logs in the following folder - 
		- %ALLUSERSPROFILE%\MinikubeConfigurator-{TimeStamp}\Logs folder.


    Usage examples
    ==============
    
    Powershell -executionpolicy bypass -file MinikubeConfigurator.ps1


    Pre-Requisites
    ==============

    - Ensure that the powershell execution policy is set to unrestricted (@TODO).


    Known issues / Caveats
    ======================
    
    - No known issues.


    Coming soon / planned work
    ==========================

    - N/A.    

##################################################################################################>

#
# Optional arguments to this script file.
#

Param(

    [switch] $Bootstrap
)

##################################################################################################

#
# Powershell Configurations
#

# Note: Because the $ErrorActionPreference is "Stop", this script will stop on first failure.  
$ErrorActionPreference = "Stop"

# Ensure that current process can run scripts. 
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force 

###################################################################################################

#
# Param and environment check
#

try {
    
    if (-not $PSCommandPath) {

        # $PSCommandPath is required
        throw "The PSCommandPath is not given."
    }
}
catch {

    $errMsg = $Error[0].Exception.Message

    Write-Error $errMsg

    Start-Sleep -Seconds 10

    throw
}

##################################################################################################

#
# Intialization
#

$ScriptName = [System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)
$ScriptFolder = Join-Path $env:ALLUSERSPROFILE -ChildPath $("$ScriptName-" + [System.DateTime]::Now.ToString("yyyy-MM-dd-HH-mm-ss"))

if (Test-Path ([System.IO.Path]::ChangeExtension($PSCommandPath, ".log")) -PathType Leaf) {

    # use the current script folder as log location as it already contains a log file
    $ScriptFolder = Split-Path -Path $PSCommandPath -Parent
}

$ScriptLog = Join-Path -Path $ScriptFolder -ChildPath "$ScriptName.log"

##################################################################################################

# 
# Description:
#  - Creates the folder structure which'll be used for dumping logs generated by this script and
#    the logon task.
#
# Parameters:
#  - N/A.
#
# Return:
#  - N/A.
#
# Notes:
#  - N/A.
#

function InitializeFolders
{
    if (-not (Test-Path -Path $ScriptFolder))
    {
        New-Item -Path $ScriptFolder -ItemType directory | Out-Null
    }
}

##################################################################################################

# 
# Description:
#  - Writes specified string to the console as well as to the script log (indicated by $ScriptLog).
#
# Parameters:
#  - $message: The string to write.
#
# Return:
#  - N/A.
#
# Notes:
#  - N/A.
#

function WriteLog
{
    Param(
        <# Can be null or empty #>
        [string]$Message,
        [switch]$LogFileOnly
    )

    "[$([System.DateTime]::Now)] $Message" | ForEach-Object {
    
        if (-not $LogFileOnly)
        {
            Write-Host -Object $_
        }
    
        Out-File -InputObject $_ -FilePath $ScriptLog -Append

    } | Out-Null
}

##################################################################################################

#
# 
#

try
{
    InitializeFolders

    if ($Bootstrap) {

        "==========================================================================================="
        "     _                          ____             _____         _     _          _          "
        "    / \    _____   _ _ __ ___  |  _ \  _____   _|_   _|__  ___| |_  | |    __ _| |__  ___  "
        "   / _ \  |_  / | | | '__/ _ \ | | | |/ _ \ \ / / | |/ _ \/ __| __| | |   / _' | '_ \/ __| "
        "  / ___ \  / /| |_| | | |  __/ | |_| |  __/\ V /  | |  __/\__ \ |_  | |__| (_| | |_) \__ \ "
        " /_/   \_\/___|\__,_|_|  \___| |____/ \___| \_/   |_|\___||___/\__| |_____\__._|_.__/|___/ "
        "==========================================================================================="

        $virtualSwitchName = "Minikube"
        $virtualSwitch = Get-VMSwitch -Name $virtualSwitchName -ErrorAction SilentlyContinue

        if (-not ($virtualSwitch)) {
            
            WriteLog "Find network adapter for new virtual switch '$virtualSwitchName' ..."
            $networkAdapter = Get-NetAdapter -Physical | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1

            if (-not ($networkAdapter)) { throw "Could not find physical network adapter to create a new virtual switch in Hyper-V." }

            WriteLog "Create new virtual switch '$virtualSwitchName' ..."
            $virtualSwitch = New-VMSwitch -Name $virtualSwitchName -NetAdapterName $networkAdapter.Name -AllowManagementOS $true 
        }
            
        $minikubeMemory = [int] ((Get-WMIObject -class Win32_PhysicalMemory | Measure-Object -Sum Capacity | Select-Object -ExpandProperty Sum) / 1MB / 4)
        $minikubeVersion = "v1.5.2" # minikube default k8s version 

        if ((minikube get-k8s-versions | Out-String) -match "(v\d+\.\d+\.\d+)(?!-)") {

            WriteLog "Find the latest k8s version supported by minikube ..."
            $minikubeVersion = ($Matches[0] | Out-String).Replace([Environment]::NewLine, [String]::Empty)
        }

        minikube start --kubernetes-version=$minikubeVersion --vm-driver=hyperv --memory=$minikubeMemory --hyperv-virtual-switch=$virtualSwitchName --v=7 --alsologtostderr

    } else {

        $postBootKey = Split-Path $ScriptFolder -Leaf
        $postBootFile = Join-Path $ScriptFolder (Split-Path $PSCommandPath -Leaf)
        $postBootCommand = "powershell.exe -ExecutionPolicy bypass -File `"$postBootFile`" -Bootstrap"

        WriteLog "Copy $PSCommandPath`n  to $postBootFile"
        Copy-Item -Path $PSCommandPath -Destination $postBootFile -Force

        WriteLog "Register RunOnce script '$postBootKey': $postBootCommand"
        Set-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Name "!$postBootKey" -Value $postBootCommand
    }
}
catch
{
    $errMsg = $Error[0].Exception.Message

    if ($errMsg)
    {
        WriteLog -Message "ERROR: $errMsg" -LogFileOnly
    }

    throw
}
