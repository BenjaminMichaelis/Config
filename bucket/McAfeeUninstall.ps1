
. $PSScriptRoot\Utils.ps1

Function Uninstall-McAfeeApplications {
    
    $infos = $null
    $infos += Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* |
    Where-object { $null -ne $_.DisplayName -and $_.SystemComponent -ne "1" } #| select DisplayName, Publisher, DisplayVersion, Uninstall
    $infos | Where-Object { $_.DisplayName -like '*McAfee*' } | ForEach-Object {
        try {
            $installedMsiObject.UnInstall()
        }
        catch {
            Write-Error "Error occurred: $_"
        }
    }
}
Uninstall-McAfeeApplications