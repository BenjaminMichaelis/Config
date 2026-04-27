<#
.SYNOPSIS
    Sets up WireGuard on-demand (auto-connect when away from trusted Wi-Fi).

.DESCRIPTION
    Installs the WireGuard Manager Service and Tunnel Service, deploys the
    on-demand runtime script, and registers a zero-poll Task Scheduler task
    triggered by EventID 10000 (network connect).

    Run interactively (default) to be prompted for all settings.
    Use -NonInteractive with explicit parameters for scripted/silent deployment.

    If not running as Administrator, the script will offer to re-launch itself
    elevated via UAC automatically.

.PARAMETER TunnelName
    Name of the WireGuard tunnel exactly as shown in the app UI.
    Required in non-interactive mode. Auto-detected in interactive mode.

.PARAMETER TrustedSSIDs
    One or more Wi-Fi network names to treat as trusted (VPN off on these).
    Required in non-interactive mode.
    Example: -TrustedSSIDs "HomeWiFi","HomeWiFi-5G"

.PARAMETER ScriptInstallDir
    Where to install the runtime script on this machine.
    Default: C:\Scripts\WireGuard

.PARAMETER TaskName
    Task Scheduler task name. Default: "WireGuard On-Demand"

.PARAMETER NonInteractive
    Suppress all prompts. Requires -TunnelName and -TrustedSSIDs.
    Note: silent deployments (RMM, GPO) should already be running as admin;
    auto-elevation is skipped in this mode.

.EXAMPLE
    # Interactive (default) — prompts for all settings, auto-elevates if needed:
    .\Install-WireGuardOnDemand.ps1

.EXAMPLE
    # Silent deployment (e.g., from a GPO or RMM — must already be admin):
    .\Install-WireGuardOnDemand.ps1 -TunnelName "MichaelisHome" `
        -TrustedSSIDs "Wi Believe I Can Fi","Wi Believe I Can Fi 5G" `
        -NonInteractive
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingWriteHost', '',
    Justification = 'Interactive installer — Write-Host is intentional for colored console output and UAC-elevation UX')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'False positive: $mgr/$tun/$tsk are used in string interpolation via null-conditional ?. operator which PSSA does not track')]
[CmdletBinding()]
param(
    [string]   $TunnelName,
    [string[]] $TrustedSSIDs,
    [string]   $ScriptInstallDir = "C:\Scripts\WireGuard",
    [string]   $TaskName         = "WireGuard On-Demand",
    [switch]   $NonInteractive
)


# Keep the window open if the script errors — without this, the elevated
# window closes instantly and the user never sees what failed.
trap {
    Write-Host ""
    Write-Host "  ══════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host "   Install failed: $_" -ForegroundColor Red
    Write-Host "  ══════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host ""
    if (-not $NonInteractive) {
        Write-Host "  Press Enter to close this window..." -ForegroundColor DarkGray
        $null = Read-Host
    }
    break
}

$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Write-Step { param($msg) Write-Host "`n[*] $msg" -ForegroundColor Cyan   }
function Write-OK   { param($msg) Write-Host "    [OK] $msg" -ForegroundColor Green }
function Write-Skip { param($msg) Write-Host "    [--] $msg" -ForegroundColor DarkGray }
function Write-Warn { param($msg) Write-Host "    [!!] $msg" -ForegroundColor Yellow }

function Read-Confirmed {
    param([string]$prompt, [bool]$defaultYes = $true)
    $hint  = if ($defaultYes) { "[Y/n]" } else { "[y/N]" }
    $raw   = (Read-Host "$prompt $hint").Trim()
    if ($raw -eq "") { return $defaultYes }
    return $raw -match '^[Yy]'
}

# ---------------------------------------------------------------------------
# Step 0 — Elevation check
# ---------------------------------------------------------------------------
$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal $identity
$isAdmin   = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    if ($NonInteractive) {
        throw "Administrator privileges required. Re-run from an elevated prompt."
    }

    Write-Host ""
    Write-Host "  Administrator rights are required." -ForegroundColor Yellow
    Write-Host "  Windows will now prompt you to allow the elevation (UAC)." -ForegroundColor Yellow
    Write-Host "  The installer will restart in a new elevated window." -ForegroundColor Yellow
    Write-Host ""
    Start-Process powershell.exe `
        -Verb RunAs `
        -ArgumentList "-ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
    exit
}

# ---------------------------------------------------------------------------
# Step 1 — Validate -NonInteractive requirements
# ---------------------------------------------------------------------------
if ($NonInteractive) {
    if (-not $TunnelName)  { throw "-TunnelName is required when using -NonInteractive." }
    if (-not $TrustedSSIDs){ throw "-TrustedSSIDs is required when using -NonInteractive." }
}

$wgExe     = "$env:ProgramFiles\WireGuard\wireguard.exe"
$logSource = "WireGuard-OnDemand"
$scriptSrc = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "wg-ondemand.ps1"

Write-Host ""
Write-Host "  WireGuard On-Demand Installer" -ForegroundColor White
Write-Host "  ==============================" -ForegroundColor DarkGray

# ---------------------------------------------------------------------------
# Step 2 — Check WireGuard is installed and runtime script is present
# ---------------------------------------------------------------------------
if (-not (Test-Path $wgExe)) {
    Write-Error "WireGuard not found at '$wgExe'.`nInstall it from https://www.wireguard.com/install/ then re-run."
}
if (-not (Test-Path $scriptSrc)) {
    Write-Error "wg-ondemand.ps1 not found next to this installer at: $scriptSrc"
}

# ---------------------------------------------------------------------------
# Step 3 — Resolve tunnel name (interactive or supplied)
# ---------------------------------------------------------------------------
Write-Step "Tunnel selection"

$dpApiDir     = "$env:ProgramFiles\WireGuard\Data\Configurations"
$dpApiFiles   = @(Get-ChildItem "$dpApiDir\*.conf.dpapi" -ErrorAction SilentlyContinue)
$foundTunnels = $dpApiFiles | ForEach-Object {
    # filename is TunnelName.conf.dpapi → strip .dpapi → strip .conf
    [System.IO.Path]::GetFileNameWithoutExtension($_.BaseName)
}

if (-not $NonInteractive) {
    if ($foundTunnels.Count -eq 0) {
        Write-Warn "No imported tunnels found in $dpApiDir"
        Write-Warn "Open the WireGuard app and import your tunnel first, then re-run."
        if (-not $TunnelName) { $TunnelName = (Read-Host "  Enter tunnel name manually").Trim() }
    }
    elseif ($foundTunnels.Count -eq 1 -and -not $TunnelName) {
        $suggested = $foundTunnels[0]
        Write-Host "    Found tunnel: $suggested"
        if (Read-Confirmed "  Use '$suggested'?") { $TunnelName = $suggested }
        else { $TunnelName = (Read-Host "  Enter tunnel name").Trim() }
    }
    elseif (-not $TunnelName) {
        Write-Host "    Found tunnels:"
        for ($i = 0; $i -lt $foundTunnels.Count; $i++) {
            Write-Host "      $($i+1). $($foundTunnels[$i])"
        }
        $pick = (Read-Host "  Select number or type a name").Trim()
        if ($pick -match '^\d+$' -and [int]$pick -ge 1 -and [int]$pick -le $foundTunnels.Count) {
            $TunnelName = $foundTunnels[[int]$pick - 1]
        } else {
            $TunnelName = $pick
        }
    }
    else {
        Write-Host "    Using supplied name: $TunnelName"
    }
}

$dpApiPath   = "$dpApiDir\$TunnelName.conf.dpapi"
$serviceName = "WireGuardTunnel`$$TunnelName"
$scriptDest  = Join-Path $ScriptInstallDir "wg-ondemand.ps1"

if (-not (Test-Path $dpApiPath)) {
    Write-Error "Config not found: '$dpApiPath'.`nImport the tunnel named '$TunnelName' in the WireGuard app first."
}
Write-OK "Tunnel: $TunnelName"

# ---------------------------------------------------------------------------
# Step 4 — Resolve trusted SSIDs (interactive or supplied)
# ---------------------------------------------------------------------------
Write-Step "Trusted Wi-Fi networks (VPN is OFF on these)"

if (-not $NonInteractive -and -not $TrustedSSIDs) {
    $collected = [System.Collections.Generic.List[string]]::new()

    # Detect the current SSID and offer it as the first trusted network
    # Take the first match only (guards against multiple adapter output).
    # Use the capture group directly instead of splitting on ':'.
    $ssidLine    = (netsh wlan show interfaces | Select-String '^\s+SSID\s+:\s+(.*)') |
                       Select-Object -First 1
    $currentSSID = if ($ssidLine) { $ssidLine.Matches[0].Groups[1].Value.Trim() } else { "" }

    if ($currentSSID) {
        Write-Host "    Currently connected to: '$currentSSID'"
        if (Read-Confirmed "  Mark '$currentSSID' as trusted? (VPN will be OFF on this network)") {
            $collected.Add($currentSSID)
            Write-OK "Added: $currentSSID"
        }
    } else {
        Write-Warn "Not connected to Wi-Fi — no SSID detected."
    }

    # Additional SSIDs
    Write-Host "    Add more trusted networks (one per line, blank to finish):"
    while ($true) {
        $extra = (Read-Host "    >").Trim()
        if ($extra -eq "") { break }
        if ($collected -notcontains $extra) {
            $collected.Add($extra)
            Write-OK "Added: $extra"
        } else {
            Write-Warn "Already in list: $extra"
        }
    }

    if ($collected.Count -eq 0) {
        Write-Warn "No trusted SSIDs — VPN will always be on."
        if (-not (Read-Confirmed "  Continue anyway?")) { exit 0 }
    }

    $TrustedSSIDs = $collected.ToArray()
} else {
    $TrustedSSIDs | ForEach-Object { Write-OK "Trusted: $_" }
}

# ---------------------------------------------------------------------------
# Step 5 — Confirm before doing anything (interactive only)
# ---------------------------------------------------------------------------
if (-not $NonInteractive) {
    Write-Host ""
    Write-Host "  ── Summary ─────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  Tunnel     : $TunnelName"
    Write-Host "  Trusted    : $($TrustedSSIDs -join ', ')"
    Write-Host "  Scripts in : $ScriptInstallDir"
    Write-Host "  Task name  : $TaskName"
    Write-Host "  ────────────────────────────────────────────────" -ForegroundColor DarkGray
    if (-not (Read-Confirmed "`n  Proceed with installation?")) { exit 0 }
}

# ---------------------------------------------------------------------------
# Step 6 — Install Manager Service (system tray, auto-starts at boot)
# ---------------------------------------------------------------------------
Write-Step "WireGuard Manager Service..."
$managerSvc = Get-Service "WireGuardManager" -ErrorAction SilentlyContinue
if ($managerSvc) {
    Write-Skip "Already installed (status: $($managerSvc.Status))"
} else {
    & $wgExe /installmanagerservice
    if ($LASTEXITCODE -ne 0) { throw "wireguard.exe /installmanagerservice failed (exit $LASTEXITCODE)" }
    Write-OK "Installed WireGuardManager"
}

# ---------------------------------------------------------------------------
# Step 9 — Deploy runtime script with injected configuration
# ---------------------------------------------------------------------------
Write-Step "Deploying wg-ondemand.ps1 to $ScriptInstallDir..."
New-Item -ItemType Directory -Force -Path $ScriptInstallDir | Out-Null
Copy-Item -Path $scriptSrc -Destination $scriptDest -Force

# Inject user's values into the deployed script using sentinel comments.
# Single-quote SSID values (escape embedded ' as '') to prevent code injection.
# Escape $ → $$ in replacement strings so the .NET regex engine treats them literally.
$ssidLines      = ($TrustedSSIDs | ForEach-Object { "    '$($_.Replace("'","''"))'" }) -join "`r`n"
$content        = Get-Content $scriptDest -Raw
$safeSSIDLines  = $ssidLines.Replace('$', '$$')
$safeTunnelName = $TunnelName.Replace('$', '$$')

# Replace SSID block between sentinel comments
$content = $content -replace '(?s)(#<<TRUSTED_SSIDS_START>>).*?(#<<TRUSTED_SSIDS_END>>)',
    "#<<TRUSTED_SSIDS_START>>`r`n$safeSSIDLines`r`n    #<<TRUSTED_SSIDS_END>>"

# Replace the $tunnelName line (matched by its trailing sentinel tag)
# Pattern uses .* to match either single- or double-quoted values on re-run.
$content = $content -replace '(?m)^\$tunnelName = .* #<<TUNNEL_NAME>>',
    "`$tunnelName = '$safeTunnelName' #<<TUNNEL_NAME>>"

$content | Set-Content $scriptDest -Encoding UTF8 -NoNewline
Write-OK "Deployed: $scriptDest"

# ---------------------------------------------------------------------------
# Step 10 — Register Windows Event Log source
# ---------------------------------------------------------------------------
Write-Step "Event Log source '$logSource'..."
if (-not [System.Diagnostics.EventLog]::SourceExists($logSource)) {
    New-EventLog -LogName Application -Source $logSource
    Write-OK "Registered"
} else {
    Write-Skip "Already registered"
}

# ---------------------------------------------------------------------------
# Step 11 — Create / replace Task Scheduler task
#            EventID 10000 fires on network connect — zero polling
# ---------------------------------------------------------------------------
Write-Step "Task Scheduler task '$TaskName'..."

$action = New-ScheduledTaskAction `
    -Execute          "powershell.exe" `
    -Argument         "-NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptDest`"" `
    -WorkingDirectory $ScriptInstallDir

$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest

$settings = New-ScheduledTaskSettingsSet `
    -MultipleInstances  IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
# Set battery properties directly — the named parameters don't exist on all Windows builds
$settings.DisallowStartIfOnBatteries = $false
$settings.StopIfGoingOnBatteries     = $false

$triggerClass = Get-CimClass `
    -Namespace Root/Microsoft/Windows/TaskScheduler `
    -ClassName  MSFT_TaskEventTrigger
$eventTrigger = New-CimInstance -CimClass $triggerClass -ClientOnly
$eventTrigger.Subscription =
    '<QueryList><Query Id="0" Path="Microsoft-Windows-NetworkProfile/Operational">' +
    '<Select Path="Microsoft-Windows-NetworkProfile/Operational">' +
    '*[System[Provider[@Name=''Microsoft-Windows-NetworkProfile''] and EventID=10000]]' +
    '</Select></Query></QueryList>'
$eventTrigger.Enabled = $true

# Boot trigger: catches networks that are already up when Task Scheduler loads,
# and ensures correct VPN state after reboot. 30s delay lets the network settle.
$bootTrigger         = New-ScheduledTaskTrigger -AtStartup
$bootTrigger.Delay   = 'PT30S'

Register-ScheduledTask `
    -TaskName   $TaskName `
    -Action     $action `
    -Trigger    @($eventTrigger, $bootTrigger) `
    -Principal  $principal `
    -Settings   $settings `
    -Description "Auto-connect/disconnect WireGuard based on trusted Wi-Fi SSID. Trigger: EventID 10000 (zero polling)." `
    -Force | Out-Null
Write-OK "Task created/updated"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
$mgr = Get-Service "WireGuardManager" -ErrorAction SilentlyContinue
$tsk = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "  ══════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "   Setup complete!" -ForegroundColor Green
Write-Host "  ══════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  WireGuardManager   : $($mgr?.Status) (startup: $($mgr?.StartType))"
Write-Host "  Task '$TaskName'    : $($tsk?.State)"
Write-Host ""
Write-Host "  Test (fires wg-ondemand.ps1 immediately):" -ForegroundColor Yellow
Write-Host "    Start-ScheduledTask -TaskName '$TaskName'"
Write-Host "    Get-EventLog -LogName Application -Source '$logSource' -Newest 5"
Write-Host ""
Write-Host "  Manual connect/disconnect:" -ForegroundColor Yellow
Write-Host "    & '$wgExe' /installtunnelservice '$dpApiPath'"
Write-Host "    & '$wgExe' /uninstalltunnelservice '$TunnelName'"
Write-Host ""
Write-Host "  If VPN doesn't connect — check WireGuard's own log:" -ForegroundColor Yellow
Write-Host "    & '$wgExe' /dumplog"
Write-Host ""
Write-Host "  To update trusted SSIDs later, re-run this installer" -ForegroundColor Yellow
Write-Host "  or edit `$trustedSSIDs directly in: $scriptDest"
Write-Host "  ══════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""

if (-not $NonInteractive) {
    Write-Host "  Press Enter to close this window..." -ForegroundColor DarkGray
    $null = Read-Host
}
