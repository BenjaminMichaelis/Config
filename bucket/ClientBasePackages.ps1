
Write-Host 'Installing and configuring OSBasePackages...'
. "$PSScriptRoot\Utils.ps1"

'bitwarden', 'powertoys', 'spotify', 'screentogif', 'brave', 'everything', 'obs-studio', 'notepad2', 'paint.net', 'microsoft-windows-terminal', 'windirstat', 'todoist-desktop', 'googlechrome'  | ForEach-Object { 
    Write-Host "Installing $_..."
    choco install -y $_
}
