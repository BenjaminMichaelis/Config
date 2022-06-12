Write-Host 'Installing and configuring OSBasePackages...'
. "$PSScriptRoot\Utils.ps1"

'nodejs-lts', 'vscode', 'gitkraken' | ForEach-Object { 
    Write-Host "Installing $_..."
    choco install -y $_
}

#hub - GitHub CLI
'hub', 'dotnet', 'VisualStudio2022Enterprise' | ForEach-Object { 
    Write-Host "Installing $_..."
    scoop install -g $_
}

Write-Host "Installing Azure CLI"
$ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; rm .\AzureCLI.msi
