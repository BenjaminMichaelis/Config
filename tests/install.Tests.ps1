Describe 'Add-ScoopBucket idempotency' {

    It 'install.ps1 uses .Name property access for bucket list comparison' {
        # The bucket-list guard line must dereference .Name so that
        # PSCustomObject instances returned by modern Scoop are compared
        # correctly against the string $name.
        $line = Get-Content -Path "$PSScriptRoot\..\install.ps1" |
            Where-Object { $_ -match 'scoop bucket list' -and $_ -match '-notcontains' }
        $line | Should -Not -BeNullOrEmpty
        $line | Should -Match '\(scoop bucket list\)\.Name\s+-notcontains'
    }

    It 'comparison logic correctly detects an existing bucket from PSCustomObjects' {
        # Simulate what modern Scoop returns: an array of PSCustomObjects
        $bucketList = @(
            [PSCustomObject]@{ Name = 'main' }
            [PSCustomObject]@{ Name = 'extras' }
        )
        $name = 'main'

        # The CORRECT check (with .Name) should say the bucket exists
        $correctResult = ($bucketList).Name -notcontains $name
        $correctResult | Should -Be $false -Because ".Name extracts strings so 'main' IS found"

        # The BUGGY check (without .Name) incorrectly says bucket is missing
        $buggyResult = ($bucketList) -notcontains $name
        $buggyResult | Should -Be $true -Because "comparing string to PSCustomObjects never matches"
    }
}
