Describe 'MicrosoftOffice365.ps1 registry value format' {
    BeforeAll {
        $script:scriptContent = Get-Content "$PSScriptRoot\..\MicrosoftOffice365.ps1" -Raw
    }

    It 'should not contain dword string syntax' {
        $script:scriptContent | Should -Not -Match 'dword:00000004'
    }

    It 'should not have duplicate GPOSetUpdateRing Set-ItemProperty calls' {
        $matchCount = ([regex]::Matches($script:scriptContent, 'Set-ItemProperty[^\r\n]*GPOSetUpdateRing')).Count
        $matchCount | Should -Be 1
    }
}

Describe 'MicrosoftOffice365.ps1 dot-source safety' {
    BeforeAll {
        # Create temp directory with a tracking Utils.ps1 stub
        $script:tempDir = [System.IO.Path]::Combine(
            [System.IO.Path]::GetTempPath(),
            'PesterMO365_' + [guid]::NewGuid().ToString('N'))
        [System.IO.Directory]::CreateDirectory($script:tempDir) | Out-Null
        $trackingUtils = @'
$global:testChocoCallCount = 0
$global:testSetItemPropertyCallCount = 0
function choco { $global:testChocoCallCount++ }
function Set-ItemProperty { $global:testSetItemPropertyCallCount++ }
function Test-Path { param([Parameter(ValueFromPipeline)]$Path) $true }
function New-Item { param($Path) [PSCustomObject]@{PSPath=$Path} }
function Invoke-RestMethod {
    param($Uri, [switch]$UseBasicParsing)
    [PSCustomObject]@{token_endpoint='https://login.windows.net/testid/oauth2/token'}
}
'@
        [System.IO.File]::WriteAllText(
            [System.IO.Path]::Combine($script:tempDir, 'Utils.ps1'), $trackingUtils)
        [System.IO.File]::Copy(
            [System.IO.Path]::Combine($PSScriptRoot, '..', 'MicrosoftOffice365.ps1'),
            [System.IO.Path]::Combine($script:tempDir, 'MicrosoftOffice365.ps1'))

        $global:testChocoCallCount = 0
        $global:testSetItemPropertyCallCount = 0
        . (Join-Path $script:tempDir 'MicrosoftOffice365.ps1')
    }

    AfterAll {
        if ($script:tempDir -and [System.IO.Directory]::Exists($script:tempDir)) {
            [System.IO.Directory]::Delete($script:tempDir, $true)
        }
    }

    It 'should not call choco when dot-sourced' {
        $global:testChocoCallCount | Should -Be 0
    }

    It 'should not call Set-OneDriveConfig when dot-sourced' {
        $global:testSetItemPropertyCallCount | Should -Be 0
    }
}
