
Write-Host "Uninstalling McAfee Applications..."

. $PSScriptRoot\Utils.ps1

Function Uninstall-McAfeeApplications {
    Write-Host "Running $($MyInvocation.MyCommand.Name)..."
    Get-Program 'McAfee*'
    Get-Program 'McAfee*' | ForEach-Object {
        try {
            Write-Host "Uninstalling $($_.Name)..."
            $UninstallCmd = $_.UninstallString
            # String up to and including the .exe
            $UninstallExecutible = $UninstallCmd.substring(0, $UninstallCmd.IndexOf(".exe") + 4 )
            # Any parts after the .exe		
            $UninstallArguments = $UninstallCmd.substring($UninstallCmd.IndexOf(".exe") + 4 )
            Start-Process -FilePath "$UninstallExecutible" -ArgumentList "$UninstallArguments" -Wait -Passthru
        }
        catch {
            Write-Error "Error occurred: $_"
        }
    }
}
Uninstall-McAfeeApplications