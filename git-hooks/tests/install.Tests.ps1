#Requires -Version 5.1
#Requires -Modules @{ModuleName="Pester";ModuleVersion="5.0"}

Describe 'install.ps1 -UsePowerShell shim' {
    BeforeAll {
        # Preserve the real global git hooks path so the test does not corrupt it
        $script:originalHooksPath = git config --global core.hooksPath 2>$null

        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "git-hooks-test-$([guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

        # Copy commit-msg.ps1 so install.ps1 can find it
        Copy-Item ([System.IO.Path]::Combine($PSScriptRoot, '..', 'commit-msg.ps1')) $tempDir -Force

        # Run install.ps1 with the temp hooks dir
        & ([System.IO.Path]::Combine($PSScriptRoot, '..', 'install.ps1')) -UsePowerShell -HooksDir $tempDir
    }

    AfterAll {
        # Restore the original git hooks path before deleting the temp dir
        if ($script:originalHooksPath) {
            git config --global core.hooksPath $script:originalHooksPath
        } else {
            git config --global --unset core.hooksPath 2>$null
        }

        if (Test-Path $tempDir) {
            Remove-Item $tempDir -Recurse -Force
        }
    }

    It 'should write the commit-msg shim without a UTF-8 BOM' {
        $shimPath = Join-Path $tempDir 'commit-msg'
        $shimPath | Should -Exist

        $bytes = [System.IO.File]::ReadAllBytes($shimPath)
        $bytes.Length | Should -BeGreaterOrEqual 3

        $hasBOM = ($bytes[0] -eq 0xEF) -and ($bytes[1] -eq 0xBB) -and ($bytes[2] -eq 0xBF)
        $hasBOM | Should -BeFalse
    }
}
