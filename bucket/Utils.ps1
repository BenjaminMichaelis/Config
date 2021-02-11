
# TODO: Generalize
$UserBucket = "BenjaminMichaelis"

if(!$env:SCOOP -and (test-path "$env:ProgramData\scoop\apps\scoop\current")) {
    $env:SCOOP = "$env:ProgramData\scoop"
}

if($env:SCOOP) {
    $currentScoopDirectory = "$env:SCOOP\apps\scoop\current"
    . (Join-Path $currentScoopDirectory 'libexec\scoop-search.ps1') > $null
}
else {
    Write-Warning '$env:SCOOP not found.'
}

Function Test-Command {
    [CmdletBinding()]
    param(
        [string]$command
    )
    return [bool](get-command $command -ErrorAction Ignore)
}

# TODO: Consider writing as a filter.
Function Test-ChocolateyPackageInstalled {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$PackageName
    )

    $installed = choco list $PackageName --local-only --no-progress | Where-Object {
        # Alternate filter
        #choco list  -localonly | Where-Object { ($_ -notmatch 'Chocolatey v[0-9\.]') -and $_ -notmatch '\d+ packages installed\.' }
        $_ -match "$PackageName\s.*"
    }
    Write-Output (@($installed).Count -gt 0)
}

Function Test-ScoopPackageInstalled {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$PackageName
    )

    $scoopOutput = scoop export $PackageName
    $installed = $scoopOutput | Where-Object {
        # Alternate filter
        #choco list  -localonly | Where-Object { ($_ -notmatch 'Chocolatey v[0-9\.]') -and $_ -notmatch '\d+ packages installed\.' }
        $_ -match "\s*$PackageName\s.*"
    }
    Write-Output (@($installed).Count -gt 0)
}

function choco {
    $installArgs = Get-InstallArgs @args
    if(
        ($installArgs.Action -eq 'install') `
        -and ($installArgs.Options -notcontains '-f') `
        -and ($installArgs.Options -notcontains '--force') `
        -and (Test-ChocolateyPackageInstalled $installArgs.Arg1)
        ) {
        Write-Warning "$($installArgs.Arg1) is already installed."
    }
    else {
        choco.exe @args
    }
}

 
function Get-LocalBucket {
    <#
    .SYNOPSIS
        List all local buckets.
    #>

    $bucketsdir = (Join-Path $env:scoop buckets)
    if($bucketsdir -ne (Split-Path (Find-BucketDirectory).Trim('bucket') -Parent)) {
        Write-Warning 'Bucket direcotry doesn''t match Find-BucketDirectory location.'
    }
    $buckets = (Get-ChildItem $bucketsdir -Directory).Name
    if($UserBucket) {
        $buckets = ,$UserBucket + ($buckets | Where-Object { $_ -ne $UserBucket })
    }
    Write-Output $buckets
}

<#
.SYNOPSIS
# Parse out the arguments used on a command
.DESCRIPTION
# Given a command, parse out the original arguments into options, "actions", and 
# additional argumenst for the action.  The assumption
# is that the first argument is the commad, e.g. choco install.  The remaining 
# arguments are arguments for the command, e.g. choco install 'VisualStudio'.  All
# original arguments beginning with a dash ('-'), are parsed as options
# to the action.
.EXAMPLE
choco install VisualStudio -y --force
.NOTES
The class should work for both scoop and chocolatey (choco), or any other
command broken into <original command> <subcommand> <arguments> <options>.
#>
class InstallArgs {
    # The complete list of original arguments, including actions and options.
    [string[]]$OriginalArgs
    # All original arguments that begin with a dash.
    [string[]]$Options
    # All the original arguments that didn't begin with a dash.
    [string[]]$SubCommands
    # The first original argument that is not an option.
    [string]$Action
    # The first SubCommand that isn't an action (in other words the second subcommand)
    [string]$Arg1

    InstallArgs([string[]]$OriginalArgs) {
        [string[]]$localSubCommands = $OriginalArgs | Where-Object { $_ -notlike '-*'}
        $this.OriginalArgs = $OriginalArgs
        $this.Options = $OriginalArgs | Where-Object { $_ -like '-*'};
        $this.SubCommands = $localSubCommands 
        $this.Action =  $localSubCommands | Select-Object -First 1;
        $this.Arg1 = $localSubCommands | Select-Object -Skip 1 | Select-Object -First 1
    }
}


function Get-InstallArgs {
    return [InstallArgs]::new($args)
}

function scoop {
    [InstallArgs]$scoopArgs = Get-InstallArgs @args
    $localArgs = $scoopArgs.OriginalArgs
    $cmd = $scoopArgs.Action
    $options = $scoopArgs.Options
    $arg1 = $scoopArgs.Arg1

    switch ($cmd) {
        'install' {  
            #Make the $UserBucket the priority.
            $null, $bucket, $null = parse_app $arg1
            if(-not $bucket) {
                scoop search $arg1 -PSCustomObject | Where-Object {
                    $_.name -match "^$args$" 
                } | Where-Object { 
                        $_.Bucket -eq $UserBucket 
                } | ForEach-Object {
                    $index = [array]::indexof($localArgs,$_.name)
                    $localArgs[$index] = "$UserBucket/$arg1"
                } 
            }
            scoop.ps1 @localArgs
        }
        'search' {
            if($options -contains '-PSCustomObject') {
                Get-LocalBucket | ForEach-Object {
                    $bucket = $_
                    search_bucket $_ $arg1 | ForEach-Object {
                        $_['Bucket'] = $bucket 
                        Write-Output ([PSCustomObject]$_)
                    }
                }
            }
            else {
                scoop.ps1 @args
            }
        }
        Default {
            scoop.ps1 @args   
        }
    }   
}

Function Get-Program {
    [CmdletBinding()] param([string] $Filter = "*") 

    $ProgramRegistryKeys = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
    "Microsoft.PowerShell.Core\Registry::HKEY_USERS\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\Uninstall"

    # REview for 32/64 Bit
    # http://gallery.technet.microsoft.com/scriptcenter/PowerShell-Installed-70d0c0f4

    $ProgramRegistryKeys | Get-ChildItem | Get-ItemProperty | 
    Select-Object  *, @{Name = "Name"; Expression = { 
            if ( ($_ | Get-Member "DisplayName") -and $_.DisplayName) {
                #Consider $_.PSObject.Properties.Match("DisplayName") as it may be faster
                $_.DisplayName
            } 
            else { 
                $_.PSChildName 
            } 
        }
    } | Where-Object { ($_.Name -Like $Filter) -or ($_.PSChildName -Like $Filter) } 
}

Function Import-ChocolateyModule {
    if (test-path env:ChocolateyInstall) {
        Import-Module (Resolve-Path -Path "$env:ChocolateyInstall\*\chocolateyInstaller.psm1").Path
        if (Test-Path Function:\Write-Host) {
            Remove-Item Function:Write-Host # Chocolatey overwrites Write-Host.  This call removes the override.  It should still occur within Chocolatey.
            # Note that this is necessary otherwise Write-Host attempts to write to the chocolatey log file in Program Data and doesn't have
            # permission outside of an admin prompt.
        }
        $env:ChocolateyAllowEmptyChecksumsSecure = $true
        $env:ChocolateyAllowEmptyChecksums = $true
        $env:ChocolateyPackageFolder = "$env:ChocolateyInstall\Lib"
        Set-PackageSource -Name chocolatey -ProviderName Chocolatey -Trusted -Force
    }
    else {
        throw "Chocolatey is not installed"
    }
}


if (!(Test-Path function:Install-WebDownload)) {
    Function Install-WebDownloadOfZip {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)][string] $PackageName,
            [Parameter(Mandatory)][alias("Uri")][string] $url,
            $UnzipLocation = "$env:ChocolateyInstall\lib\$PackageName"
        )

        Import-ChocolateyModule

        # See Chocolatey's Get-CheckSumValid.ps1 for more info.
        $originalChocolateyAllowEmptyChecksums = $env:ChocolateyAllowEmptyChecksums
        $originalChocolateyAllowEmptyChecksumsSecure = $env:ChocolateyAllowEmptyChecksumsSecure
        try {
            # Needed because Chocolatey is not setting up context.
            if (!(test-path variable:\helpersPath)) {
                $setHelpersPath = $true
                $global:helpersPath = $env:ChocolateyInstall
            }

            $env:ChocolateyAllowEmptyChecksums = 'true'
            $env:ChocolateyAllowEmptyChecksumsSecure = 'true'
            Install-ChocolateyZipPackage -packageName $PackageName -url $url -unzipLocation $UnzipLocation -specificFolder ''
            Get-ChildItem $UnzipLocation *.exe | ForEach-Object { Install-BinFile -name TrayIt -path $_.FullName }
        }
        finally {
            if ($setHelpersPath) {
                remove-item variable:\global:helpersPath
            }
            $env:ChocolateyAllowEmptyChecksums = $originalChocolateyAllowEmptyChecksums
            $env:ChocolateyAllowEmptyChecksumsSecure = $originalChocolateyAllowEmptyChecksumsSecure
        }
    }


    Function Install-WebDownload {
        [CmdletBinding()] param(
            [Parameter(Mandatory)][alias("Uri")][string] $url,
            [Parameter(Mandatory)][string] $PackageName,
            [Parameter(ParameterSetName = "CommandLine")] [string] $arguments = $null,
            [Parameter(ParameterSetName = "ScriptBlock")][ScriptBlock] $postDownloadScriptBlock,
            [Parameter(ParameterSetName = "UnattendedSilentSwitchFinder",
                HelpMessage = "Lookup the unattended silent switch for the setup program.")][switch]$ussf,
            [string] $installFileName = [System.Management.Automation.WildcardPattern]::Escape((Split-Path $url -Leaf)),
            [switch]$forceDownload )

        #TODO Switch to Get-ChocolateyWebFile and use Invoke-WebRequest as fallback.
        $tempPath = Get-TempPath

        if ([IO.Path]::GetExtension($InstallFileName) -eq ".zip") {
            Install-WebDownloadOfZip -Uri $url -packageName $PackageName
        }
        else {
            $installFileName = Join-Path $tempPath $installFileName

            if ($forceDownload -OR ($installFileName -eq "Setup.exe") -OR !(Test-Path $installFileName) ) {
                Invoke-WebRequest $url -OutFile $installFileName
            }

            if ($ussf) {
                ussf $installFileName
            }
            else {
                If ( ([string]::IsNullOrWhiteSpace($PsCmdlet.ParameterSetName)) -or ($PsCmdlet.ParameterSetName -eq "CommandLine") ) {
                    $postDownloadScriptBlock = [ScriptBlock] {
                        $process = Start-Process $installFileName $arguments -PassThru -wait
                        return $process.ExitCode
                    }
                }
            }
            Write-Output (Invoke-Command $postDownloadScriptBlock)
        }
    }
}
