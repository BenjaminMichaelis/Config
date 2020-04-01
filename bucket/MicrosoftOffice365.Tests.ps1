
Describe Install-MicrosoftOffice365 {
    $meScript = $PSCommandPath
    $InstallName = ((Split-Path $meScript -Leaf) -replace '.Tests.ps1', '')
    scoop export | Where-Object { 
        $_ -like "*$installName*"
    } | Foreach-Object {
        scoop uninstall $_
    }
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