# Static analysis tests for this script live in bucket/tests/McAfeeUninstall.Tests.ps1 (run in CI).
# The test below is a Scoop integration test that requires Scoop installed locally.

. "$PSScriptRoot\Utils.ps1"

Describe Install-McAfeeUninstall {
    it "scoop install McAfeeUninstall" {
        $meScript = $PSCommandPath
        $InstallName = ((Split-Path $meScript -Leaf) -replace '.Tests.ps1', '')
        if(Test-ScoopPackageInstalled $InstallName) { scoop uninstall $installName }
        $manifestPath = "$PSScriptRoot\McAfeeUninstall.json"
        $manifestJson = Get-Content $manifestPath
        $manifest = $manifestJson | ConvertFrom-Json
        $manifest.url = $manifest.url | Where-Object { $_ -notmatch '^https://TODO' } | ForEach-Object {
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
}