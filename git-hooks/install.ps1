#Requires -Version 5.1
# Installs the global git commit-msg hook on Windows.
# Configures git to use %LOCALAPPDATA%\git\hooks as the global hooks directory.
#
# Two installation modes are supported:
#   1. Bash hook   – copies commit-msg (works via Git for Windows' bundled bash)
#   2. PowerShell hook – copies commit-msg.ps1 plus a thin bash shim named
#      commit-msg that calls pwsh so native PowerShell handles the filtering.
#
# By default, mode 1 (bash) is used.  Pass -UsePowerShell to use mode 2.

param(
    [switch]$UsePowerShell,
    [string]$HooksDir = (Join-Path $env:LOCALAPPDATA 'git\hooks')
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not (Test-Path $HooksDir)) {
    New-Item -ItemType Directory -Path $HooksDir -Force | Out-Null
}

if ($UsePowerShell) {
    # Copy the PowerShell hook script
    Copy-Item (Join-Path $ScriptDir 'commit-msg.ps1') (Join-Path $HooksDir 'commit-msg.ps1') -Force

    # Write a minimal bash shim that delegates to pwsh
    $shim = @'
#!/usr/bin/env bash
pwsh -NoProfile -NonInteractive -ExecutionPolicy Bypass \
     -File "$(dirname "$0")/commit-msg.ps1" "$1"
'@
    [System.IO.File]::WriteAllText(([System.IO.Path]::Combine($HooksDir, 'commit-msg')), $shim, (New-Object System.Text.UTF8Encoding $false))
    Write-Host "Installed PowerShell commit-msg hook → $HooksDir"
} else {
    Copy-Item "$ScriptDir\commit-msg" "$HooksDir\commit-msg" -Force
    Write-Host "Installed bash commit-msg hook → $HooksDir"
}

git config --global core.hooksPath $HooksDir
Write-Host "Global git hooks path set to: $HooksDir"
