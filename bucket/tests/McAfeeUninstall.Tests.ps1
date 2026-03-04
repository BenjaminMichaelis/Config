Describe 'McAfeeUninstall.json - BOM and URL validation' {
    BeforeAll {
        $script:jsonPath = "$PSScriptRoot\..\McAfeeUninstall.json"
    }

    It 'should not start with a UTF-8 BOM' {
        $bytes = [System.IO.File]::ReadAllBytes($script:jsonPath)
        ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) | Should -BeFalse
    }

    It 'should not contain broken fragment URLs with hash-slash pattern' {
        $content = Get-Content $script:jsonPath -Raw
        $content | Should -Not -Match '#/'
    }

    It 'should be valid JSON' {
        $content = Get-Content $script:jsonPath -Raw
        { $content | ConvertFrom-Json } | Should -Not -Throw
    }
}

Describe 'McAfeeUninstall.ps1 - Case-sensitive IndexOf fix' {
    BeforeAll {
        $script:scriptContent = Get-Content "$PSScriptRoot\..\McAfeeUninstall.ps1" -Raw
    }

    It 'should use OrdinalIgnoreCase with all IndexOf calls' {
        $caseSensitiveCalls = [regex]::Matches($script:scriptContent, 'IndexOf\(".exe"\)')
        $caseSensitiveCalls.Count | Should -Be 0
    }

    It 'should guard against IndexOf returning -1' {
        $script:scriptContent | Should -Match '-eq -1'
    }
}

Describe 'McAfeeUninstall.ps1 - No auto-execution on dot-source' {
    BeforeAll {
        $script:scriptContent = Get-Content "$PSScriptRoot\..\McAfeeUninstall.ps1" -Raw
    }

    It 'should guard the top-level function call with invocation check' {
        $script:scriptContent | Should -Match 'MyInvocation\.InvocationName'
    }
}
