
Write-Host 'Installing and configuring OSBasePackages...'
. "$PSScriptRoot\Utils.ps1"

'bitwarden' | ForEach-Object { 
    Write-Host "Installing $_..."
    choco install -y $_
}


