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
$tiuxPath = Join-Path $scriptsDir "tiux.ps1"
$untrustedPath = Join-Path $scriptsDir "untrusted1nstaller-runas.ps1"
$tiuxShim = Join-Path $installDir "tiux.cmd"
$untrustedShim = Join-Path $installDir "untrusted1nstaller-runas.cmd"

Write-Host "Creating script directory at: $scriptsDir"
New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null

# ------------------ Write tiux.ps1 ------------------
Write-Host "Writing tiux.ps1..."
$tiuxScript = @'
#Requires -RunAsAdministrator
#Requires -Modules NtObjectManager

$TIUX_VERSION = "1.0.1"

function Log($msg) {
    Write-Output "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [INFO]  $msg"
}
function LogError($msg) {
    Write-Error "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [ERROR]  $msg"
}
function LogStep($msg) {
    Write-Output "`n$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [STEP]  $msg"
}
function Check-Admin {
    $currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        LogError "This script must be run as Administrator."
        exit 1
    }
}
function Resolve-Executable {
    param([string]$inputCmd)
    # Try to resolve using Get-Command first
    try {
        $cmd = Get-Command $inputCmd -ErrorAction Stop
        return $cmd.Source
    } catch {
        # Continue to manual resolution if Get-Command fails.
    }
    # Check if inputCmd is a valid path
    if (Test-Path $inputCmd) {
        return (Resolve-Path $inputCmd).Path
    }
    # Try appending .exe if not present
    if (-not $inputCmd.EndsWith(".exe")) {
        $exeTry = "$inputCmd.exe"
        if (Test-Path $exeTry) {
            return (Resolve-Path $exeTry).Path
        }
    }
    # Search each directory in PATH manually
    foreach ($dir in $env:Path.Split(";")) {
        $possible = Join-Path $dir "$inputCmd.exe"
        if (Test-Path $possible) {
            return (Resolve-Path $possible).Path
        }
    }
    return $null
}

Check-Admin

if ($Args.Count -eq 1 -and ($Args[0] -eq "--version" -or $Args[0] -eq "-v")) {
    Write-Host "tiux version $TIUX_VERSION"
    exit 0
}
if ($Args.Count -lt 1) {
    Write-Host "Usage: tiux <ApplicationPath> [args...] or tiux --version"
    exit 1
}

$AppName = $Args[0]
$RemainingArgs = if ($Args.Count -gt 1) { $Args[1..($Args.Count - 1)] } else { @() }

$ApplicationPath = Resolve-Executable $AppName
$runViaCmd = $false

if (-not $ApplicationPath) {
    Log "Application not found as file, assuming it's a system command."
    # Fallback: use full path to cmd.exe to run the command
    $ApplicationPath = "$env:WINDIR\System32\cmd.exe"
    $cmdArgs = $Args -join " "
    $RemainingArgs = @("/c", $cmdArgs)
    $runViaCmd = $true
}

$logPath = "$env:TEMP\tiux-log.txt"
Start-Transcript -Path $logPath -Force

LogStep "Initializing tiux run"
Log "Resolved ApplicationPath: $ApplicationPath"

try {
    if (-not (Get-Module -ListAvailable -Name NtObjectManager)) {
        Log "NtObjectManager not found. Installing..."
        Install-Module NtObjectManager -Scope CurrentUser -Force -SkipPublisherCheck | Out-Null
    }
    Import-Module NtObjectManager -ErrorAction Stop
    Log "NtObjectManager successfully imported."
} catch {
    LogError "Failed to load NtObjectManager: $_"
    Stop-Transcript
    exit 1
}

try {
    sc.exe stop TrustedInstaller | Out-Null
    sc.exe config TrustedInstaller binpath= "C:\Windows\servicing\TrustedInstaller.exe" | Out-Null
    sc.exe start TrustedInstaller | Out-Null
} catch {
    LogError "Could not restart TrustedInstaller: $_"
    Stop-Transcript
    exit 1
}

try {
    $tiPID = (Get-CimInstance Win32_Service -Filter "Name='TrustedInstaller'").ProcessId
    if (-not $tiPID) { throw "No PID for TrustedInstaller" }
    $p = Get-NtProcess | Where-Object { $_.ProcessId -eq $tiPID }
    if (-not $p) { throw "Could not get NT process object" }
} catch {
    LogError "Failed to acquire TrustedInstaller process: $_"
    Stop-Transcript
    exit 1
}

try {
    # Build the command line (escaped arguments if any)
    $escapedArgs = $RemainingArgs | ForEach-Object { if ($_ -match "\s") { '"' + $_ + '"' } else { $_ } }
    $commandLine = '"' + $ApplicationPath + '" ' + ($escapedArgs -join ' ')
    Log "Final command line: $commandLine"
    $proc = New-Win32Process -CommandLine $commandLine -CreationFlags NewConsole -ParentProcess $p
    Log "Process launched → PID: $($proc.ProcessId)"
} catch {
    LogError "Failed to launch process: $_"
    Stop-Transcript
    exit 1
}

Log "Done. Log at $logPath"
Stop-Transcript
'@
Set-Content -Path $tiuxPath -Value $tiuxScript -Encoding UTF8

# ------------------ Write untrusted1nstaller-runas.ps1 ------------------
Write-Host "Writing untrusted1nstaller-runas.ps1..."
$untrustedScript = @'
#Requires -RunAsAdministrator
#Requires -Modules NtObjectManager

param (
    [Parameter(Mandatory = $true)][string]$ApplicationPath
)

if (-not (Test-Path $ApplicationPath)) {
    $resolvedPath = Join-Path -Path (Get-Location) -ChildPath $ApplicationPath
    if (Test-Path $resolvedPath) {
        $ApplicationPath = $resolvedPath
    } else {
        Write-Error "File not found: $ApplicationPath"
        exit 1
    }
}

$logPath = "$env:TEMP\untrusted1nstaller-log.txt"
Start-Transcript -Path $logPath -Force

Import-Module NtObjectManager -ErrorAction Stop

sc.exe stop TrustedInstaller | Out-Null
sc.exe config TrustedInstaller binpath= "C:\Windows\servicing\TrustedInstaller.exe" | Out-Null
sc.exe start TrustedInstaller | Out-Null

$tiPID = (Get-CimInstance Win32_Service -Filter "Name='TrustedInstaller'").ProcessId
$p = Get-NtProcess | Where-Object { $_.ProcessId -eq $tiPID }

$proc = New-Win32Process $ApplicationPath -CreationFlags NewConsole -ParentProcess $p
Write-Output "Spawned → PID: $($proc.ProcessId)"

Stop-Transcript
'@
Set-Content -Path $untrustedPath -Value $untrustedScript -Encoding UTF8

# ------------------ Create CMD Shims ------------------
Write-Host "Creating .cmd shims..."
Set-Content -Path $tiuxShim -Value "@echo off`r`nPowerShell -ExecutionPolicy Bypass -NoProfile -File `"%~dp0scripts\tiux.ps1`" %*" -Encoding ASCII
Set-Content -Path $untrustedShim -Value "@echo off`r`nPowerShell -ExecutionPolicy Bypass -NoProfile -File `"%~dp0scripts\untrusted1nstaller-runas.ps1`" %*" -Encoding ASCII

# ------------------ Add to PATH ------------------
$envPath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
if (-not $envPath.Split(";") -contains $installDir) {
    Write-Host "Adding $installDir to system PATH using setx..."
    $newPath = "$envPath;$installDir"
    cmd.exe /c "setx Path `"$newPath`" /M"
} else {
    Write-Host "Path already contains $installDir"
}

Write-Host "[+] tiux installed successfully!"
Write-Host "Try: 'tiux notepad' or 'tiux .\tool.exe'"
