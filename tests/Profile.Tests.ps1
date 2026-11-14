BeforeDiscovery {
    $script:Hosts = @()
    foreach ($exe in 'powershell', 'pwsh') {
        if (Get-Command $exe -ErrorAction SilentlyContinue) { $script:Hosts += @{ Exe = $exe } }
    }
}

BeforeAll {
    $script:ProfilePath = (Resolve-Path "$PSScriptRoot\..\Profile.ps1").Path
    $script:FakeHome = Join-Path ([IO.Path]::GetTempPath()) "profile-tests-$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $script:FakeHome | Out-Null

    # Runs a child shell with an isolated HOME so the profile's update check
    # and log files can't touch the real user profile.
    function Invoke-ChildShell {
        param([string]$Exe, [string[]]$Arguments, [string]$StdIn)
        $oldHome = $env:HOME; $oldProfile = $env:USERPROFILE
        $env:HOME = $script:FakeHome; $env:USERPROFILE = $script:FakeHome
        try {
            if ($PSBoundParameters.ContainsKey('StdIn')) { $StdIn | & $Exe @Arguments 2>&1 }
            else { & $Exe @Arguments 2>&1 }
        } finally {
            $env:HOME = $oldHome; $env:USERPROFILE = $oldProfile
        }
    }
}

AfterAll {
    Remove-Item -LiteralPath $script:FakeHome -Recurse -Force -ErrorAction SilentlyContinue
}

# Regression: programs such as the Vectorworks Install Manager run
# `powershell.exe Write-Output PSPresent` and require *exactly* that output.
# The profile's welcome banner / update prompt must not appear in scripted sessions.
Describe 'Profile.ps1 in non-interactive sessions (<Exe>)' -ForEach $script:Hosts {

    It 'prints nothing extra with -Command' {
        $out = Invoke-ChildShell -Exe $Exe -Arguments @(
            '-NoProfile', '-Command', ". '$script:ProfilePath'; Write-Output PSPresent")
        ($out -join "`n").Trim() | Should -BeExactly 'PSPresent'
    }

    It 'prints nothing extra when run via -File' {
        $wrapper = Join-Path $script:FakeHome 'wrapper.ps1'
        ". '$script:ProfilePath'`nWrite-Output PSPresent" | Set-Content -LiteralPath $wrapper
        $out = Invoke-ChildShell -Exe $Exe -Arguments @('-NoProfile', '-File', $wrapper)
        ($out -join "`n").Trim() | Should -BeExactly 'PSPresent'
    }

    It 'prints nothing extra when commands are piped over stdin' {
        $out = Invoke-ChildShell -Exe $Exe -Arguments @('-NoProfile', '-Command', '-') `
            -StdIn ". '$script:ProfilePath'; Write-Output PSPresent"
        ($out -join "`n").Trim() | Should -BeExactly 'PSPresent'
    }

    It 'skips startup work (update check, prompt customisation) entirely' {
        # Check-ForUpdates is defined and invoked at startup; in a scripted session
        # the profile must return before reaching it.
        $out = Invoke-ChildShell -Exe $Exe -Arguments @(
            '-NoProfile', '-Command',
            ". '$script:ProfilePath' | Out-Null; [bool](Get-Command Check-ForUpdates -ErrorAction SilentlyContinue)")
        ($out | Select-Object -Last 1).ToString().Trim() | Should -BeExactly 'False'
    }
}

Describe 'Test-InteractiveProfileSession' {
    BeforeAll {
        # Evaluated in an isolated child shell. The helper is defined before the
        # profile's early return, so it is callable after dot-sourcing even there.
        function Get-Decision {
            param([string[]]$CommandLineArgs, [bool]$InputRedirected, [bool]$OutputRedirected)
            $argList = ($CommandLineArgs | ForEach-Object { "'$_'" }) -join ','
            $cmd = ". '$script:ProfilePath' | Out-Null; " +
                "Test-InteractiveProfileSession -CommandLineArgs @($argList) " +
                "-InputRedirected `$$InputRedirected -OutputRedirected `$$OutputRedirected"
            $out = Invoke-ChildShell -Exe 'pwsh' -Arguments @('-NoProfile', '-Command', $cmd)
            ($out | Select-Object -Last 1).ToString().Trim()
        }
    }

    It 'is interactive for a plain console launch' {
        Get-Decision @('powershell.exe', '-NoLogo') $false $false | Should -BeExactly 'True'
    }

    It 'is interactive with -NoExit' {
        Get-Decision @('pwsh.exe', '-NoExit') $false $false | Should -BeExactly 'True'
    }

    It 'is not interactive with <_>' -ForEach '-Command', '-c', '-File', '-EncodedCommand', '-NonInteractive' {
        Get-Decision @('powershell.exe', $_, 'x') $false $false | Should -BeExactly 'False'
    }

    It 'is not interactive when output is captured (powershell.exe Write-Output X)' {
        Get-Decision @('powershell.exe', 'Write-Output', 'X') $false $true | Should -BeExactly 'False'
    }

    It 'is not interactive when input is piped' {
        Get-Decision @('powershell.exe') $true $false | Should -BeExactly 'False'
    }
}
