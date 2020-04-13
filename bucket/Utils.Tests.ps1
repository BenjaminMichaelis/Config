
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace('.Tests', '')
. "$PSScriptRoot\$sut"

Describe "Test-ScoopPackageInstalled" {
    Mock scoop.ps1 { 
        Write-Output @"
Installed apps matching 'MyMockApp':

  MyMockApp 1.00.001 [C:\Users\mark\AppData\Local\Temp\MicrosoftOffice365.json]
  MyMockApp 1.00.001 *global* [C:\Users\mark\AppData\Local\Temp\MicrosoftOffice365.json]
"@ } `
-ParameterFilter { 
    foreach($arg in $args)
    {
        if ($arg -notlike '-*')  {
            return ($arg -eq 'export') 
        }
    }
    return $true
}

    it "MyMockApp is installed " {
        Test-ScoopPackageInstalled 'MyMockApp' | Should Be $true
    }
    it "MicrosoftOffice365 is NOT installed " {
        Test-ScoopPackageInstalled 'MicrosoftOffice365' | Should Be $false
    }
}

Describe 'scoop search wrapper' {
    [bool]$script:firstBucket=$true
    $mockAppName = 'MyMockApp'
    Mock apps_in_bucket {
        $script:firstBucket = $false
        Write-Output $mockAppName,'Application1','Application2' 
    } -ParameterFilter { $firstBucket }
    Mock latest_version {
        '42.42.001'
    }
    #Mock Find-BucketDirectory { }
    
    It 'scoop search has -PSCustomObject option' {
        $results = scoop search $mockAppName -PSCustomObject 
        $results | Should Not Be $null
        $results.count | Should Not Be 1
        $results.GetType() | Should Be 'System.Management.Automation.PSCustomObject'
        $results.Name | Should Be $mockAppName
        $results.Bucket | Should Be (Get-LocalBucket | Select-Object -First 1)
    }
}


Describe 'Get-LocalBucket' {
    It 'Get-LocalBucket' {
        $localBuckets = Get-LocalBucket
        $localBuckets -contains 'main' | Should Be $true
        if($UserBucket) {
            $localBuckets[0] | Should Be 'MarkMichaelis'
        }
    }
}


Describe 'scoop install wrapper' {
    # [bool]$script:firstBucket=$true
    $mockAppName = 'dotnet'
    Mock scoop.ps1 { 
        Write-Output "$args" } `
-ParameterFilter { 
    foreach($arg in $args)
    {
        if ($arg -notlike '-*')  {
            return ($arg -eq 'install') 
        }
    }
    return $false
}
    
    It 'scoop install ' {
        $results = scoop install $mockAppName
        # $fullAppName = scoop search $mockAppName -PSCustomObject | Where-Object {
        #     $_.name -match "^$mockAppName$"
        # } | ForEach-Object { 
        #     "$($_.Bucket)/$($_.name)"
        # }
        $results | Should Be "install $mockAppName"
    }
}