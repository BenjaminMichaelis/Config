
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace('.Tests', '')
. "$PSScriptRoot\$sut"

Function scoop {
    scoop.ps1 @args
}
Describe "Test-ScoopPackageInstalled" {
    Mock scoop { 
        Write-Output @"
Installed apps matching 'MyMockApp':

  MyMockApp 1.00.001 [C:\Users\mark\AppData\Local\Temp\MicrosoftOffice365.json]
  MyMockApp 1.00.001 *global* [C:\Users\mark\AppData\Local\Temp\MicrosoftOffice365.json]
"@ } `
-ParameterFilter { 
    Write-Host 'Inside ParaeterFilter'
    foreach($arg in $args)
    {
        Write-Host 'Inside ParaeterFilter=>foreach'
        if ($arg -notlike '-*')  {
            Write-Host 'Inside ParaeterFilter=>foreach=>if'
            return ($arg -eq 'export') 
        }
    }
    Write-Host 'Inside ParaeterFilter=>after foreach'
    return $true
}

    it "MyMockApp is installed " {
        Test-ScoopPackageInstalled 'MyMockApp' | Should Be $true
    }
    it "MicrosoftOffice365 is NOT installed " {
        Test-ScoopPackageInstalled 'MicrosoftOffice365' | Should Be $false
    }
}