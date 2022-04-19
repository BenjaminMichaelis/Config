Write-Host 'Installing and configuring OSBasePackages...'
. "$PSScriptRoot\Utils.ps1"

'nodejs', 'vscode' | ForEach-Object { 
    Write-Host "Installing $_..."
    choco install -y $_
}

#hub - GitHub CLI
'hub', 'dotnet', 'VisualStudio2022Enterprise' | ForEach-Object { 
    Write-Host "Installing $_..."
    scoop install -g $_
}
