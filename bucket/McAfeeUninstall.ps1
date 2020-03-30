
. $PSScriptRoot\Utils.ps1

Function Uninstall-McAfeeApplications {
    
    Get-Program 'McAfee*' | ForEach-Object {
        try {
            Write-Host "Uninstalling $($_.Name)..."
            $_.UnInstall()
        }
        catch {
            Write-Error "Error occurred: $_"
        }
    }
}
Uninstall-McAfeeApplications