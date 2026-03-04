. "$PSScriptRoot\Utils.ps1"

Function Uninstall-McAfeeApplications {
    Get-Program 'McAfee*' | ForEach-Object {
        try {
            Write-Host "Uninstalling $($_.Name)..."
            $UninstallCmd = $_.UninstallString
            # String up to and including the .exe
            $exeIndex = $UninstallCmd.IndexOf(".exe", [StringComparison]::OrdinalIgnoreCase)
            if ($exeIndex -eq -1) {
                Write-Error "Cannot find .exe in uninstall string: $UninstallCmd"; return
            }
            $UninstallExecutible = $UninstallCmd.substring(0, $exeIndex + 4)
            # Any parts after the .exe
            $UninstallArguments = $UninstallCmd.substring($exeIndex + 4)
            $parms = @{
                "FilePath" = "$UninstallExecutible";
                "Wait"     = $true;
                "PassThru" = $true;
            }
            if (-not [string]::IsNullOrWhiteSpace($UninstallArguments)) {
                $parms.Add("ArgumentList", "$UninstallArguments")
            }
            Start-Process @parms
        }
        catch {
            Write-Error "Error occurred: $_"
        }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "Uninstalling McAfee Applications..."
    Uninstall-McAfeeApplications
}
