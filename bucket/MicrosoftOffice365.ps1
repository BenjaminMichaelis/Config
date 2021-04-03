
. "$PSScriptRoot\Utils.ps1"

#if(-not (Test-ChocolateyPackageInstalled 'Office365ProPlus')) {
    choco install Office365ProPlus -y
#}

#if(-not (Test-ChocolateyPackageInstalled 'Microsoft-Teams')) {
    choco install Microsoft-Teams -y
#}

Function Get-Office365TenantId {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory,ValueFromPipeline)][string]$TenantName
    )
    Invoke-RestMethod -Uri "https://login.windows.net/$TenantName.onmicrosoft.com/.well-known/openid-configuration" -UseBasicParsing | `
        Select-Object 'token_endpoint' | Where-Object { 
            $_ -match 'https://login.windows.net/(?<TenantId>.+)/oauth2/token' 
        } | Foreach-object { [PSCustomObject]$matches } | Select-Object TenantId
}

Function Set-OneDriveConfig {

    if(-not (Test-Path 'HKCU:\SOFTWARE\Policies\Microsoft\OneDrive')) {
        New-Item -Path 'HKCU:\SOFTWARE\Policies\Microsoft\OneDrive'
    }
    if(-not (Test-Path 'HKCU:\SOFTWARE\Policies\Microsoft\OneDrive\DefaultRootDir')) {
        New-Item -Path 'HKCU:\SOFTWARE\Policies\Microsoft\OneDrive\DefaultRootDir'
    }
    # TOTO: Remove hardcoding
    Set-ItemProperty -Path 'HKCU:\SOFTWARE\Policies\Microsoft\OneDrive\DefaultRootDir' -Name "$(Get-Office365TenantId 'IntelliTectSP')" -Value "C:\OneDrive\IntelliTect"
    Set-ItemProperty -Path 'HKCU:\SOFTWARE\Policies\Microsoft\OneDrive\DefaultRootDir' -Name "$(Get-Office365TenantId 'Michaelises')" -Value "C:\OneDrive\Michaelises"

    <# 
    Set the default OneDrive location
    See https://docs.microsoft.com/en-us/onedrive/use-group-policy#set-the-default-location-for-the-onedrive-folder
    #>
    Set-ItemProperty -path 'HKLM:\SOFTWARE\Policies\Microsoft\OneDrive' -name 'GPOSetUpdateRing' -value 'dword:00000004'

    <#
    We release OneDrive sync app (OneDrive.exe) updates to the public through three rings- first to 
    Insiders, then Production, and finally Enterprise. This setting lets you specify the ring for 
    users in your organization. When you enable this setting and select a ring, users aren't able 
    to change it.
    - Insiders (4) ring users receive builds that let them preview new features coming to OneDrive.
    - Production (5) ring users get the latest features as they become available. This ring is the default.
    - Enterprise (0) ring users get new features, bug fixes, and performance improvements last. This 
    ring lets you deploy updates from an internal network location, and control the timing of the 
    deployment (within a 60-day window).
    See https://docs.microsoft.com/en-us/onedrive/sync-client-update-process
    #>
    Set-ItemProperty -path 'HKLM:\SOFTWARE\Policies\Microsoft\OneDrive' -name 'GPOSetUpdateRing' -value 'dword:00000004'
}
Set-OneDriveConfig

