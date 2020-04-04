
Write-Host 'Installing and configuring OSBasePackages...'
. "$PSScriptRoot\Utils.ps1"

'7zip', 'notepad2', 'Everything', 'GoogleChrome', 'SysInternals', 'WinDirStat', `
    'microsoft-windows-terminal', 'fzf', 'procexp' | Where-Object {
    Write-Host "Testing for install of chocolatey pacakge $_ $(Test-ChocolateyPackageInstalled $_)..."
    -not (Test-ChocolateyPackageInstalled $_)
} | ForEach-Object { 
    Write-Host "Installing $_..."
    choco install -y $_
}


