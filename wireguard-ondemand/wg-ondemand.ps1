# ============================================================
#  wg-ondemand.ps1
#  WireGuard On-Demand — Runtime Script
#
#  Called by Task Scheduler on every network connect
#  (EventID 10000, Microsoft-Windows-NetworkProfile/Operational)
#  and at system startup.
#  Checks the current Wi-Fi SSID and connects or disconnects
#  the WireGuard tunnel accordingly.
#
#  No polling. Zero background processes.
# ============================================================

# ============================================================
#  CONFIGURATION
#  Managed by Install-WireGuardOnDemand.ps1, or edit directly.
#  The installer uses the sentinel comments to inject values;
#  do not remove or rename them.
# ============================================================

# Trusted (home/work) network names. VPN is OFF on these, ON everywhere else.
# Wired connections (no SSID) are treated as untrusted — VPN will engage.
$trustedSSIDs = @(
    #<<TRUSTED_SSIDS_START>>
    'YourHomeSSID'
    #<<TRUSTED_SSIDS_END>>
)

# Tunnel name exactly as it appears in the WireGuard app UI.
$tunnelName = 'YourTunnelName' #<<TUNNEL_NAME>>

# ============================================================
#  END CONFIGURATION — do not edit below this line
# ============================================================

$wgExe       = "$env:ProgramFiles\WireGuard\wireguard.exe"
$dpApiPath   = "$env:ProgramFiles\WireGuard\Data\Configurations\$tunnelName.conf.dpapi"
$serviceName = "WireGuardTunnel`$$tunnelName"
$logSource   = "WireGuard-OnDemand"

# Self-register event log source if the installer hasn't run yet on this boot.
if (-not [System.Diagnostics.EventLog]::SourceExists($logSource)) {
    New-EventLog -LogName Application -Source $logSource -ErrorAction SilentlyContinue
}

try {
    if (-not (Test-Path $wgExe)) { throw "wireguard.exe not found at: $wgExe" }

    # Brief settle delay: EventID 10000 fires before DHCP/DNS are fully settled.
    # The SSID is readable immediately, but this avoids edge-case race conditions.
    Start-Sleep -Seconds 2

    # Get the current Wi-Fi SSID.
    # 'netsh wlan show interfaces' lists all adapters; grab the first SSID line
    # (not BSSID, which also contains "SSID"). Empty string if wired/no Wi-Fi.
    $ssidLine    = netsh wlan show interfaces | Select-String '^\s+SSID\s+:\s+(.*)' |
                       Select-Object -First 1
    $currentSSID = if ($ssidLine) { $ssidLine.Matches[0].Groups[1].Value.Trim() } else { "" }

    if ($trustedSSIDs -contains $currentSSID) {
        # On a trusted network — disconnect VPN if running.
        # WireGuard tunnel services are ephemeral: they self-uninstall on stop,
        # so we must use /uninstalltunnelservice instead of Stop-Service.
        $svc = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if (-not $svc) {
            $msg = "already disconnected."
        } else {
            $wgOut  = & $wgExe /uninstalltunnelservice $tunnelName 2>&1
            $wgExit = $LASTEXITCODE
            Start-Sleep -Milliseconds 1500
            $svcAfter = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            $msg = if (-not $svcAfter) {
                "disconnected (wg exit $wgExit)."
            } else {
                "disconnect FAILED (wg exit $wgExit, still present). wg output: $wgOut"
            }
        }
        Write-EventLog -LogName Application -Source $logSource `
                       -EventId 1001 -EntryType Information `
                       -Message "WireGuard: Trusted SSID='$currentSSID' tunnel='$tunnelName' — $msg" `
                       -ErrorAction SilentlyContinue
    } else {
        # Untrusted/unknown network or wired — engage VPN.
        # /installtunnelservice creates + starts the service from the encrypted config.
        $svc = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -eq 'Running') {
            $msg = "already connected."
        } else {
            if (-not (Test-Path $dpApiPath)) {
                throw "Tunnel config not found: $dpApiPath — re-import tunnel in the WireGuard app."
            }
            # Uninstall any lingering stopped/stale service first.
            # If a previous run left a stopped service, /installtunnelservice silently fails.
            if ($svc) {
                & $wgExe /uninstalltunnelservice $tunnelName 2>&1 | Out-Null
                Start-Sleep -Milliseconds 500
            }
            $wgOut  = & $wgExe /installtunnelservice $dpApiPath 2>&1
            $wgExit = $LASTEXITCODE
            Start-Sleep -Milliseconds 1500
            $svcAfter = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            $msg = if ($svcAfter -and $svcAfter.Status -in 'Running', 'StartPending') {
                "connected (wg exit $wgExit)."
            } else {
                "connect FAILED (wg exit $wgExit, state: $($svcAfter?.Status)). wg output: $wgOut"
            }
        }
        Write-EventLog -LogName Application -Source $logSource `
                       -EventId 1000 -EntryType Information `
                       -Message "WireGuard: Untrusted SSID='$currentSSID' tunnel='$tunnelName' — $msg" `
                       -ErrorAction SilentlyContinue
    }
} catch {
    Write-EventLog -LogName Application -Source $logSource `
                   -EventId 9999 -EntryType Error `
                   -Message "WireGuard on-demand error: $_" `
                   -ErrorAction SilentlyContinue
}