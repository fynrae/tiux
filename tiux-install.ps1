# Full tiux installer script
# Run as Administrator

function Check-Admin {
    $currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Error "This script must be run as Administrator."
        exit 1
    }
}

Check-Admin

$installDir = "C:\Program Files\tiux"
$scriptsDir = Join-Path $installDir "scripts"
$ps1Path = Join-Path $scriptsDir "tiux.ps1"
$shimPath = Join-Path $installDir "tiux.cmd"

# Create folder structure
Write-Host "Creating tiux installation directory at: $scriptsDir"
New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null

# Write tiux.ps1
Write-Host "Writing tiux.ps1 to $ps1Path"
$tiuxScript = @'
#Requires -RunAsAdministrator
#Requires -Modules NtObjectManager

$TIUX_VERSION = "1.0.0"

function Log { param([string]$msg) Write-Output "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [INFO]  $msg" }
function LogError { param([string]$msg) Write-Error "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [ERROR] $msg" }
function LogStep { param([string]$msg) Write-Output "`n$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [STEP]  $msg" }
function Check-Admin {
    $currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        LogError "This script must be run as Administrator."
        exit 1
    }
}

Check-Admin

if ($Args.Count -eq 1 -and ($Args[0] -eq "--version" -or $Args[0] -eq "-v")) {
    Write-Host "tiux version $TIUX_VERSION"
    exit 0
}
if ($Args.Count -lt 1) {
    Write-Host "Usage: tiux <ApplicationPath> or tiux --version"
    exit 1
}

$logPath = "$env:TEMP\untrusted1nstaller-log.txt"
Start-Transcript -Path $logPath -Force

$ApplicationPath = $Args -join " "

LogStep "Initializing tiux run"
Log "Script invoked as: $($MyInvocation.MyCommand.Definition)"
Log "Running User: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)"
Log "Command Line Argument: $ApplicationPath"
Log "Temporary Log File: $logPath"

LogStep "Importing NtObjectManager module"
try {
    Install-Module NtObjectManager -Scope CurrentUser -Force -SkipPublisherCheck | Out-Null
    Import-Module NtObjectManager -ErrorAction Stop
    Log "NtObjectManager successfully imported."
} catch {
    LogError "Failed to import NtObjectManager. $_"
    Stop-Transcript
    exit 1
}

LogStep "Restarting TrustedInstaller service"
try {
    sc.exe stop TrustedInstaller | Out-Null
    Start-Sleep -Seconds 2
    sc.exe config TrustedInstaller binpath= "C:\Windows\servicing\TrustedInstaller.exe" | Out-Null
    sc.exe start TrustedInstaller | Out-Null
    Start-Sleep -Seconds 3
} catch {
    LogError "Could not restart TrustedInstaller service. $_"
    Stop-Transcript
    exit 1
}

LogStep "Getting TrustedInstaller PID"
try {
    $tiService = Get-CimInstance Win32_Service -Filter "Name='TrustedInstaller'"
    $tiPID = $tiService.ProcessId
    if (-not $tiPID -or $tiPID -eq 0) {
        throw "TrustedInstaller service returned invalid PID: $tiPID"
    }
} catch {
    LogError "Failed to get TrustedInstaller PID. $_"
    Stop-Transcript
    exit 1
}

LogStep "Acquiring NT process object for PID: $tiPID"
try {
    $p = Get-NtProcess | Where-Object { $_.ProcessId -eq $tiPID }
    if (-not $p) {
        throw "Get-NtProcess did not return a process object for PID $tiPID"
    }
    Log "NT Process Retrieved: $($p.Name) (PID $($p.ProcessId))"
} catch {
    LogError "Failed to get NT process for PID $tiPID. $_"
    Stop-Transcript
    exit 1
}

LogStep "Launching application as TrustedInstaller"
try {
    $proc = New-Win32Process $ApplicationPath -CreationFlags NewConsole -ParentProcess $p
    Log "[+] Process launched successfully."
    Log "    → PID: $($proc.ProcessId)"
} catch {
    LogError "Failed to spawn process. $_"
    Stop-Transcript
    exit 1
}

LogStep "Execution complete."
Log "Log file stored at: $logPath"
Stop-Transcript
'@

Set-Content -Path $ps1Path -Value $tiuxScript -Encoding UTF8

# Write tiux.cmd shim
Write-Host "Creating shim: $shimPath"
$cmdShim = "@echo off`nPowerShell -ExecutionPolicy Bypass -NoProfile -File `"%~dp0scripts\tiux.ps1`" %*"
Set-Content -Path $shimPath -Value $cmdShim -Encoding ASCII

# Add installDir to system PATH if not already present
$envPath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
if (-not ($envPath.Split(";") -contains $installDir)) {
    Write-Host "Adding $installDir to system PATH..."
    [System.Environment]::SetEnvironmentVariable("Path", "$envPath;$installDir", "Machine")
} else {
    Write-Host "PATH already contains $installDir"
}

Write-Host ""
Write-Host "tiux installed successfully!"
Write-Host 'You can now run:'
Write-Host '    tiux notepad.exe'
Write-Host 'Or check version:'
Write-Host '    tiux --version'
