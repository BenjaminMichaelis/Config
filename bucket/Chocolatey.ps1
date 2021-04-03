Write-Host 'Installing and configuring Chocolatey...'

. "$PSScriptRoot\Utils.ps1"

Function Install-Chocolatey {
    
    if (-not (Test-Command choco)) {
        Write-Output "Installing Chocolatey..."
        Invoke-WebRequest https://chocolatey.org/install.ps1 -UseBasicParsing | Invoke-Expression
    }
    Write-Output "Configuring Chocolatey..."
    choco feature enable -n allowglobalconfirmation
    choco feature enable -n allowEmptyChecksums
    choco feature enable -n allowEmptyChecksumsSecure

    #Set environment variables so the above options are true when directly calling Chocolatey functions/commands:
    [Environment]::SetEnvironmentVariable("ChocolateyAllowEmptyChecksums", $true)
    [Environment]::SetEnvironmentVariable("ChocolateyAllowEmptyChecksumsSecure", $true)
    [Environment]::SetEnvironmentVariable("ChocolateyToolsLocation", "$env:ChocolateyInstall\Tools")

    # TODO: Figure repository for API Key
    if (Test-Path C:\data\Profile\ChocolateyAPIKey.txt) {
        Get-Content C:\data\Profile\ChocolateyAPIKey.txt | Foreach-Object { choco setapikey $_ }
    }

    choco install chocolatey-core.extension -y

    choco install au -y # Automatic Chocolatey Package Update

    if (Test-Path C:\Dropbox\Profile\chocolatey.license.xml) {
        [string]$chocolateyLicenseFolder = (Join-Path "$env:ChocolateyInstall" 'License')
        mkdir $chocolateyLicenseFolder
        # TODO: Figure out repository for chocolatey license.
        #TODO: Switch to use New-Item.
        cmd /c mklink (Join-Path $chocolateyLicenseFolder chocolatey.license.xml) C:\Dropbox\Profile\chocolatey.license.xml
    }

    Import-ChocolateyModule
}
Install-Chocolatey
