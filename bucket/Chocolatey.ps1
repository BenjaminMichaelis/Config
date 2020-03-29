. $PSScriptRoot\Utils.ps1

Function Install-Chocolatey {

    if (Get-Command -name choco -ErrorAction Ignore) {
        Write-Information 'Chocolatey is already installed and configured.'
        return
    }

    if (-not (Test-Command choco)) {
        Invoke-WebRequest https://chocolatey.org/install.ps1 -UseBasicParsing | Invoke-Expression
    }
    choco feature enable -n allowglobalconfirmation
    choco feature enable -n allowEmptyChecksums
    choco feature enable -n allowEmptyChecksumsSecure

    #Set environment variables so the above options are true when directly calling Chocolatey functions/commands:
    [Environment]::SetEnvironmentVariable("ChocolateyAllowEmptyChecksums", $true)
    [Environment]::SetEnvironmentVariable("ChocolateyAllowEmptyChecksumsSecure", $true)
    [Environment]::SetEnvironmentVariable("ChocolateyToolsLocation", "$env:ChocolateyInstall\Tools")

    if (Test-Path C:\data\Profile\ChocolateyAPIKey.txt) {
        Get-Content C:\data\Profile\ChocolateyAPIKey.txt | Foreach-Object { choco setapikey $_ }
    }

    choco install chocolatey.extension

    choco install au # Automatic Chocolatey Package Update

    [string]$chocolateyLicenseFolder = (Join-Path "$env:ChocolateyInstall" 'License')
    mkdir $chocolateyLicenseFolder
    #TODO: Switch to use New-Item.
    cmd /c mklink (Join-Path $chocolateyLicenseFolder chocolatey.license.xml) C:\Dropbox\Profile\chocolatey.license.xml

    Import-ChocolateyModule
}
Install-Chocolatey
