
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace('.Tests', '')
. "$PSScriptRoot\$sut"

Describe 'Test-ChocolateyPackageInstalled' {
    $mockInstalledPackageName = 'MyMockPackage'
    Mock choco.exe {
        Write-Output "Chocolatey v0.10.15"
        $installArgs = Get-InstallArgs @args
        if($installArgs.Arg1 -eq $mockInstalledPackageName) {
            Write-Output @"
chocolatey 0.10.15
$mockInstalledPackageName 1.1.2.20161210
"@
        }
        Write-Output "2 packages installed."
    } -ParameterFilter { 
        $installArgs = Get-InstallArgs @args
        return (($installArgs.Action -eq 'list'))
    }
    
    It "$mockInstalledPackageName IS installedd" {
        Test-ChocolateyPackageInstalled $mockInstalledPackageName | Should Be $true
    }
    It "$mockInstalledPackageName is NOT installedd" {
        Test-ChocolateyPackageInstalled 'NotInstalledMockPackageNAme' | Should Be $false
    }
}

Describe 'choco install' {
    $previouslyInstalledPackage = 'MyMockPackage'
    Mock choco.exe {
        $installArgs = Get-InstallArgs @args
        switch($installArgs.Action) 
        {
            'install' {
                Write-Output "Installing $($installArgs.Arg1)"
            }
            'list' {
                Write-Output "Chocolatey v0.10.15"
                if($installArgs.Arg1 -eq $previouslyInstalledPackage) {
                    Write-Output @"
chocolatey 0.10.15
$previouslyInstalledPackage 1.1.2.20161210
"@
                }
                Write-Output "2 packages installed."
            }
            Default {
                throw 'Invalid operation: Parameter filter should prevent getting here.'
            }
        }
    } -ParameterFilter { 
        $installArgs = Get-InstallArgs @args
        return (($installArgs.Action -in 'install','list'))
    }
    
    It "choco install $previouslyInstalledPackage" {
        choco install  $previouslyInstalledPackage 3>&1 | Should Be "$previouslyInstalledPackage is already installed."
    }
    It "choco install NewSamplePackage" {
        choco install NewSamplePackage | Should Be 'Installing NewSamplePackage'
    }
}

Describe "Test-ScoopPackageInstalled" {
    $mockExistingAppName = 'MyMockApp'
    $mockMissingAppName = 'MyMockMissingApp'

    Mock scoop.ps1 { 
        Write-Output @"
Installed apps matching '$mockExistingAppName':

  $mockExistingAppName 1.00.001 [...\Temp\MyMockApp.json]
  $mockExistingAppName 1.00.001 *global* [...\Temp\MyMockApp.json]
"@ } -ParameterFilter { 
        $scoopArgs = Get-InstallArgs @args
        return (($scoopArgs.Action -eq 'export'))
    }

    it "$mockExistingAppName is installed " {
        Test-ScoopPackageInstalled $mockExistingAppName | Should Be $true
    }
    it "$mockMissingAppName is NOT installed " {
        Test-ScoopPackageInstalled $mockMissingAppName | Should Be $false
    }
}

Describe 'Get-InstallArgs' {
    It 'install stuff' {
        $scoopArgs = Get-InstallArgs install stuff
        $scoopArgs.Action | Should Be 'install'
        $scoopArgs.Arg1 | Should Be 'stuff'
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
    $scoopArgs = Get-InstallArgs @args
    return (($scoopArgs.Action -eq 'install'))
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