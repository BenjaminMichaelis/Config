BeforeAll {
    $script:FileContent = Get-Content -Path "$PSScriptRoot\..\GitConfigure.ps1" -Raw
}

Describe 'GitConfigure.ps1 static analysis' {

    Context 'Install-Module posh-git parameters (Bug 1)' {
        It 'should not use -y flag on Install-Module' {
            $script:FileContent | Should -Not -Match 'Install-Module.*\-y(\s|$)'
        }

        It 'should not have malformed -Scope -AllUsers' {
            $script:FileContent | Should -Not -Match '-Scope\s+-AllUsers'
        }
    }

    Context 'HardLink -Path and -Target (Bug 2)' {
        It 'should have -Path pointing to USERPROFILE\.gitconfig on the HardLink line' {
            $hardLinkLine = ($script:FileContent -split "`n") | Where-Object { $_ -match 'HardLink' }
            $hardLinkLine | Should -Match '-Path\s+"\$env:USERPROFILE\\\.gitconfig"'
        }

        It 'should have -Target pointing to Data\Profile\.gitconfig on the HardLink line' {
            $hardLinkLine = ($script:FileContent -split "`n") | Where-Object { $_ -match 'HardLink' }
            $hardLinkLine | Should -Match '-Target\s+"\$env:Data\\Profile\\\.gitconfig"'
        }
    }
}
