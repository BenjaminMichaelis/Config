. "$PSScriptRoot\Utils.ps1"
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace('.Tests', '')
. "$PSScriptRoot\$sut"

Describe Install-MicrosoftOffice365 {
    $meScript = $PSCommandPath
    $installName = ((Split-Path $meScript -Leaf) -replace '.Tests.ps1', '')
    if(Test-ScoopPackageInstalled $InstallName) { scoop uninstall $installName }
    $manifestPath = "$PSScriptRoot\MicrosoftOffice365.json"
    $manifestJson = Get-Content $manifestPath
    $manifest = $manifestJson | ConvertFrom-Json
    $manifest.url = $manifest.url | ForEach-Object {
        [Uri]$mockUri = $_ -replace 'https://raw.githubusercontent.com/MarkMichaelis/ScoopBucket/master/bucket', "$PSScriptRoot"
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