# Static analysis tests for this script live in bucket/tests/MicrosoftOffice365.Tests.ps1 (run in CI).
# The test below is a Scoop integration test that requires Scoop installed locally.

Describe 'Install-MicrosoftOffice365' {
    BeforeAll {
        . "$PSScriptRoot\Utils.ps1"
        $meScript = $PSCommandPath
        $script:installName = ((Split-Path $meScript -Leaf) -replace '.Tests.ps1', '')
        if(Test-ScoopPackageInstalled $script:installName) { scoop uninstall $script:installName }
        $manifestPath = "$PSScriptRoot\MicrosoftOffice365.json"
        $manifestJson = Get-Content $manifestPath
        $manifest = $manifestJson | ConvertFrom-Json
        $manifest.url = $manifest.url | ForEach-Object {
            [Uri]$mockUri = $_ -replace 'https://raw.githubusercontent.com/BenjaminMichaelis/ScoopBucket/master/bucket', "$PSScriptRoot"
            Write-Output $mockUri.AbsoluteUri
        }
        $mockManifestPath = (Join-Path $env:TEMP (Split-Path -Leaf $manifestPath)) 
        try {
            scoop hold scoop
            $manifest | ConvertTo-Json | Out-File $mockManifestPath
            scoop install $mockManifestPath
        }
        finally {
            Remove-Item -force -Path $mockManifestPath -ErrorAction Ignore
            scoop unhold scoop
        }
    }

    It 'should install successfully' {
        $script:installName | Should -Not -BeNullOrEmpty
    }
}
