
. "$PSScriptRoot\Utils.ps1"
. "$PSScriptRoot\GitIntegrationWithBeyondCompare.ps1"

Function GitConfigure {
    Write-Host "Running $($MyInvocation.MyCommand.Name)..."

    # TODO: Set .ssh
    # See https://msdn.microsoft.com/en-us/powershell/wmf/5.0/feedback_symbolic?f=255&MSPPError=-2147217396
    if ($env:Data -and (Test-Path "$env:Data")) {
        New-Item -ItemType Junction -Path "$env:USERPROFILE\.ssh" -Target "$env:Data\Profile\.ssh"
        New-Item -ItemType HardLink -Target "$env:USERPROFILE\.gitconfig" -Path "$env:Data\Profile\.gitconfig"
    }

    Import-ChocolateyModule

    #Note "choco install git" installs git for Windows (not git on the command line)
    if (-not (Test-Command git)) {
        choco install git -y  -params '"/GitOnlyOnPath /NoAutoCrlf"'
        #/GitOnlyOnPath  <# this puts gitinstall\cmd on path. This is also done by default if no package parameters are set. #>
        #/NoAutoCrlf"    <# This setting only affects new installs, it will not override an existing .gitconfig. This will ensure 'Checkout as is, commit as is' #>
    }

    choco install poshgit -y # -force -allowclobber
    #Import-Module (Get-Childitem $env:PSModulePath.Split(';') posh-git.psm1 -Recurse -ErrorAction Ignore).FullName

    Invoke-GitIntegrationWithBeyondCompare

    git config --global color.ui 'auto'
    git config --global push.default 'simple'
    git config --global color.status.untracked "red normal bold"
    git config --global color.status.changed "red normal bold"
    git config --global color.status.add "green normal bold"
    git config --global color.status.added "green normal bold"
    git config --global color.status.updated "green normal bold"
    git config --global color.branch.current "green normal bold"
    git config --global color.branch.remote bold # equivalent to yellow normal bold
    git config --global color.diff.old "red normal bold"
    git config --global color.diff.new "green normal bold"

    choco install git-credential-manager-for-windows -y

    choco install gitextensions -y
    choco install gitkraken -y

    choco install hub -y

    # TODO: Check if already configured.
    # TODO: Remove hard coding if the information.
    if (-not (git config --global user.name)) {
        git config --global user.name "Benjamin Michaelis"
    }
    if (-not (git config --global user.email)) {
        git config --global user.email "benjamin@michaelis.net"
    }
}
GitConfigure
