. "$PSScriptRoot\Utils.ps1"


Function Invoke-GitConfigVisualStudio {
    if(-not (test-command vswhere)) {
        choco install vswhere
    }

    $vsInstallPath=vswhere -prerelease -latest -property installationPath
    if(-not ($vsInstallPath) ) {
        Write-Warning 'Visual Studio not installed'
        return
    }

    git config --global mergetool.visual-studio.path "\`"$vsInstallPath\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer\vsdiffmerge.exe\`" \`"`$REMOTE\`" \`"`$LOCAL\`" \`"`$BASE\`" \`"`$MERGED\`" //m"
    git config --global mergetool.visual-studio.keepBackup false
    git config --global mergetool.visual-studio.trustExitCode true
    git config --global difftool.visual-studio.cmd "\`"$vsInstallPath\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer\vsdiffmerge.exe\`" \`"`$LOCAL\`" \`"`$REMOTE\`" //t"
    git config --global difftool.visual-studio.keepBackup false

}
Invoke-GitConfigVisualStudio