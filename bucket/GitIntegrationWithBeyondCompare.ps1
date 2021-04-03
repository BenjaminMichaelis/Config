
. "$PSScriptRoot\Utils.ps1"


Function Invoke-GitIntegrationWithBeyondCompare {
    Write-Warning "Integration with Beyond Compare is not working below."
    $beyondComparePath = "${env:ProgramFiles}\Beyond Compare 4\BComp.exe"
    if ( (Test-Path $beyondComparePath) -AND (Get-Command git -ErrorAction Ignore) ) {
        git config --global diff.tool bc
        git config --global difftool.bc.path $beyondComparePath
        git config --global merge.tool bc
        git config --global merge.bc.path $beyondComparePath
    }
    <#
    if(Get-Command git -ErrorAction Ignore) {
        git config --global difftool.bc.path "$(${env:ProgramFiles}.Replace('\','/'))/beyond compare 4/bcomp.exe"
        git config --global mergetool.bc.path "$(${env:ProgramFiles}.Replace('\','/'))/beyond compare 4/bcomp.exe"
    }
    if( (Test-Path "${env:ProgramFiles}\beyond compare 4\BCompare.exe") -AND (Get-Command git -ErrorAction Ignore) ) {
        [string]$beyondComparePath = (Resolve-Path "$(${env:ProgramFiles})/beyond compare 4/bcomp.exe").Path
        [string]$gitBC4Command = '\"' + $beyondComparePath.Replace('\','/') +'\"'
        git config --global mergetool.bc.cmd ($gitBC4Command + ' \"$LOCAL\" \"$REMOTE\" -savetarget=\"$MERGED\"')
        git config --global mergetool.bc.path $gitBC4Command
        git config --global merge.tool bc
        # Beyond Compare Pro: git config --global mergetool.bc4.cmd ($gitBC4Command + ' \"$LOCAL\" \"$REMOTE\" \"$BASE\" \"$MERGED\"')
        git config --global mergetool.bc.trustExitCode true
        git config --global mergetool.keepBackup false

        git config --global diff.tool bc
        git config --global difftool.bc.cmd ($gitBC4Command + ' \"$LOCAL\" \"$REMOTE\"')
        git config --global difftool.bc.path $gitBC4Command
        git config --global --add difftool.prompt false

        git config --global alias.dt "difftool --dir-diff" #Add git dt for folder diff.
    }
    #>
}
Invoke-GitIntegrationWithBeyondCompare