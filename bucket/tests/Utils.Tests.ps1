Describe 'Utils.ps1 static text checks' {
    BeforeAll {
        $script:utilsContent = Get-Content -Path "$PSScriptRoot\..\Utils.ps1" -Raw
    }

    It 'scoop install uses $arg1 (not $args) in bucket-priority regex' {
        $script:utilsContent | Should -Not -Match '\$_\.name\s+-match\s+"\^\$args\$"'
    }

    It 'Install-BinFile uses $PackageName (not hardcoded TrayIt)' {
        $script:utilsContent | Should -Not -Match 'Install-BinFile\s+-name\s+TrayIt'
    }
}
