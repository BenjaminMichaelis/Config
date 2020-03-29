
Function Test-Command {
    [CmdletBinding()]
    param(
        [string]$command
    )
    return [bool](get-command $command -ErrorAction Ignore)
}

# TODO: Consider writing as a filter.
Function Test-ChocolateyPackageInstalled {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)][string]$PackageName
    )

    [bool] $installed = choco list $PackageName --local-only --no-progress | Where-Object {
        $_ -match "$PackageName\s.*"
    }
    Write-Output $installed
}

'7zip', 'notepad2', 'Everything', 'GoogleChrome', 'SysInternals', 'WinDirStat' | Where-Object {
    Test-ChocolateyPackageInstalled $_
} | ForEach-Object { 
    choco install -y $_
}

