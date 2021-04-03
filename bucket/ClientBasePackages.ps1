
Write-Host 'Installing and configuring OSBasePackages...'
. "$PSScriptRoot\Utils.ps1"

'' | ForEach-Object { 
    Write-Host "Installing $_..."
    choco install -y $_
}


