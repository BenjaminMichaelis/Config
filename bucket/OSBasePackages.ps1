
. $PSScriptRoot\Utils.ps1

'7zip', 'notepad2', 'Everything', 'GoogleChrome', 'SysInternals', 'WinDirStat', `
    'microsoft-windows-terminal', 'fzf' | Where-Object {
    Test-ChocolateyPackageInstalled $_
} | ForEach-Object { 
    choco install -y $_
}


