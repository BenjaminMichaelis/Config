#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validates PowerShell syntax in Profile.ps1
.DESCRIPTION
    This script checks for common PowerShell syntax issues, particularly
    the variable reference error where $variable: is used in double-quoted strings.
#>

$ErrorActionPreference = 'Stop'

Write-Host "Validating PowerShell syntax..." -ForegroundColor Cyan

# Parse the Profile.ps1 file
$profilePath = Join-Path $PSScriptRoot "Profile.ps1"
if (-not (Test-Path $profilePath)) {
    Write-Host "Error: Profile.ps1 not found at $profilePath" -ForegroundColor Red
    exit 1
}

# Check for parser errors
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($profilePath, [ref]$null, [ref]$errors)

if ($errors) {
    Write-Host "Parser errors found:" -ForegroundColor Red
    $errors | ForEach-Object {
        Write-Host "  Line $($_.Extent.StartLineNumber): $($_.Message)" -ForegroundColor Red
    }
    exit 1
} else {
    Write-Host "✓ No parser errors found" -ForegroundColor Green
}

# Check for potential variable reference issues
# Pattern: $variable: in double-quoted strings (not including valid scope modifiers)
$content = Get-Content $profilePath -Raw
$lines = Get-Content $profilePath

$issuesFound = $false
for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    # Check for problematic pattern: "$var:" where var is not env, script, global, etc.
    if ($line -match '"\$([a-zA-Z_][a-zA-Z0-9_]*):' -and 
        $line -notmatch '"\$(env|script|global|local|private|using):' -and
        $line -notmatch '::\\' -and  # Not a path like C:\
        $line -notmatch '::') {      # Not a static method call
        
        $varName = $matches[1]
        # Additional check: this pattern is only an issue if it's a direct variable reference
        # $(...): is fine, ${...}: needs checking
        if ($line -match "\`$${varName}:[^:]") {
            Write-Host "Warning: Potential variable reference issue at line $($i + 1):" -ForegroundColor Yellow
            Write-Host "  $line" -ForegroundColor Yellow
            Write-Host "  Consider using `${$varName} or string formatting instead of `$${varName}:" -ForegroundColor Yellow
            $issuesFound = $true
        }
    }
}

if (-not $issuesFound) {
    Write-Host "✓ No problematic variable reference patterns found" -ForegroundColor Green
}

# Try to dot-source the profile to ensure it loads correctly
try {
    $null = . $profilePath
    Write-Host "✓ Profile loads successfully" -ForegroundColor Green
} catch {
    Write-Host "Error loading profile: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`nValidation complete!" -ForegroundColor Green
exit 0
