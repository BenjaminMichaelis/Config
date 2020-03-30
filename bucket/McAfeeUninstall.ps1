
. $PSScriptRoot\Utils.ps1

Write-Host "Uninstalling McAfee Applications..."

Function Uninstall-McAfeeApplications {
    Write-Host "Running $($MyInvocation.MyCommand.Name)..."
    
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