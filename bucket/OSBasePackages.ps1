
Write-Host 'Installing and configuring OSBasePackages...'
. $PSScriptRoot\Utils.ps1

'7zip', 'notepad2', 'Everything', 'GoogleChrome', 'SysInternals', 'WinDirStat', `
    'microsoft-windows-terminal', 'fzf' | Where-Object {
    Test-ChocolateyPackageInstalled $_
} | ForEach-Object { 
    Write-Host "Installing $_..."
    choco install -y $_
}


