
Write-Host 'Installing and configuring OSBasePackages...'
. "$PSScriptRoot\Utils.ps1"

'bitwarden', 'powertoys', 'spotify', 'screentogif', 'brave', 'everything' | ForEach-Object { 
    Write-Host "Installing $_..."
    choco install -y $_
}
