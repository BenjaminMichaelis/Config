# --- Configuration ------------------------------------------------------------
# Ensure TLS 1.2+ for GitHub APIs on older PowerShell
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
} catch { }

$repoOwner       = "BenjaminMichaelis"
$repoName        = "Config"
$repoBranch      = "main"
$repoFilePath    = "Profile.ps1"
$repoContentUrl  = "https://api.github.com/repos/$repoOwner/$repoName/contents/$repoFilePath?ref=$repoBranch"
$repoCommitsUrl  = "https://api.github.com/repos/$repoOwner/$repoName/commits?path=$repoFilePath&sha=$repoBranch&per_page=1"
$checkInterval   = 4              # Hours
$updateCheckFile = [System.IO.Path]::Combine($HOME, ".profile_update_check")
$localProfilePath = $Profile.CurrentUserCurrentHost
# Keep logs close to HOME but make logging robust
$logFile         = [System.IO.Path]::Combine($HOME, "profile_update_log.txt")
$versionFile     = [System.IO.Path]::Combine($HOME, "PSRemoteProfileVersions.json")

# --- Helpers -----------------------------------------------------------------
function Ensure-Directory {
    param([Parameter(Mandatory)][string]$Path)
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

# Robust logger: mutex + append stream + retries (prevents file-in-use errors)
$script:LogMutexName = "Local\\PSProfileUpdateLogMutex_Benjamin"
function Log-Message {
    param([string]$Message)

    try {
        Ensure-Directory -Path $logFile
        $line = "{0}: {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message

        $m = [System.Threading.Mutex]::new($false, $script:LogMutexName)
        try {
            if ($m.WaitOne([TimeSpan]::FromSeconds(2))) {
                try {
                    $attempts = 0
                    while ($attempts -lt 5) {
                        try {
                            $fs = [System.IO.File]::Open($logFile, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write, [System.IO.FileShare]::ReadWrite)
                            try {
                                $sw = New-Object System.IO.StreamWriter($fs)
                                $sw.WriteLine($line)
                                $sw.Flush()
                                $sw.Dispose()
                            } finally {
                                $fs.Dispose()
                            }
                            break
                        } catch {
                            Start-Sleep -Milliseconds 150
                            $attempts++
                        }
                    }
                } finally {
                    try { $m.ReleaseMutex() | Out-Null } catch { }
                }
            }
        } finally {
            $m.Dispose()
        }
    } catch {
        # Swallow all logging errors to avoid breaking the session
    }
}

# Function to show differences between two strings
function Show-Diff {
    param (
        [string[]]$OldContent,
        [string[]]$NewContent
    )
    Write-Host "[+] Added Lines" -ForegroundColor Green
    $NewContent | ForEach-Object { if ($_ -notin $OldContent) { Write-Host $_ -ForegroundColor Green } }

    Write-Host "[-] Removed Lines" -ForegroundColor Red
    $OldContent | ForEach-Object { if ($_ -notin $NewContent) { Write-Host $_ -ForegroundColor Red } }
}

# --- Gist Update Logic -------------------------------------------------------
function Check-ForUpdates {
    param ([bool]$force = $false)

    Log-Message "Checking for updates (force: $force)"

    # Initialize last check timestamp from file or default
    if (-not $env:PROFILE_LAST_CHECK) {
        if (Test-Path -LiteralPath $updateCheckFile) {
            $env:PROFILE_LAST_CHECK = (Get-Content -Path $updateCheckFile -Raw).Trim()
        } else {
            $env:PROFILE_LAST_CHECK = (Get-Date).AddHours(-($checkInterval + 1)).ToString("yyyy-MM-dd HH:mm:ss")
        }
    }

    try {
        $lastCheck = [datetime]::ParseExact($env:PROFILE_LAST_CHECK, "yyyy-MM-dd HH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture)
    } catch {
        $lastCheck = (Get-Date).AddHours(-($checkInterval + 1))
    }
    $nextCheck = $lastCheck.AddHours($checkInterval)

    if ($force -or $nextCheck -lt (Get-Date)) {
        try {
            # Add User-Agent header for better GitHub API compatibility
            $headers = @{
                'User-Agent' = 'PSProfileUpdater'
                'Accept' = 'application/vnd.github+json'
            }
            
            $contentResponse = Invoke-RestMethod -Uri $repoContentUrl -Headers $headers -ErrorAction Stop
            Log-Message "Fetched repository file metadata."

            $rawUrl = $contentResponse.download_url
            if (-not $rawUrl) {
                Log-Message "Repository content metadata missing download URL."
                return
            }

            $repoProfileContent = Invoke-RestMethod -Uri $rawUrl -Headers $headers -ErrorAction Stop
            $remoteBlobSha = $contentResponse.sha

            $commitResponse = Invoke-RestMethod -Uri $repoCommitsUrl -Headers $headers -ErrorAction Stop
            $commitArray = @($commitResponse)
            $latestCommit = if ($commitArray.Count -gt 0) { $commitArray[0] } else { $null }

            if (-not $latestCommit) {
                Log-Message "Unable to determine latest commit for repository profile file."
                return
            }

            $lastModified = $latestCommit.commit.author.date
            $lastCommitHash = $latestCommit.sha

            # Load version data
            if (Test-Path -LiteralPath $versionFile) {
                $versionData = Get-Content -Path $versionFile -Raw | ConvertFrom-Json
            } else {
                $versionData = [PSCustomObject]@{
                    LastModified   = "1900-01-01T00:00:00Z"
                    LastCommitHash = "None"
                    LastBlobSha    = "None"
                }
            }

            if (-not $versionData.PSObject.Properties.Match('LastBlobSha')) {
                $versionData | Add-Member -NotePropertyName LastBlobSha -NotePropertyValue "None"
            }

            if (($versionData.LastModified -ne $lastModified) -or ($versionData.LastCommitHash -ne $lastCommitHash) -or ($versionData.LastBlobSha -ne $remoteBlobSha)) {
                Write-Host "-----------------------------------------"
                Write-Host "Local Last Modified: $(([datetime]$versionData.LastModified).ToLocalTime())"
                Write-Host "Remote Last Modified: $(([datetime]$lastModified).ToLocalTime())"
                Write-Host "Local Commit Hash: $($versionData.LastCommitHash)"
                Write-Host "Remote Commit Hash: $lastCommitHash"
                Write-Host "Local Blob SHA: $($versionData.LastBlobSha)"
                Write-Host "Remote Blob SHA: $remoteBlobSha"
                Write-Host "-----------------------------------------"

                # Show diff if we have a previous version and the local profile exists
                if (-not $versionData.LastModified.Equals("1900-01-01T00:00:00Z") -and (Test-Path -LiteralPath $localProfilePath)) {
                    try {
                        $currentProfile = Get-Content -Path $localProfilePath -Raw
                        Show-Diff -OldContent ($currentProfile -split "`r?`n") -NewContent ($repoProfileContent -split "`r?`n")
                    } catch {
                        Log-Message "Could not read current profile for diff: $($_.Exception.Message)"
                    }
                }

                # Prompt to accept or deny updates
                $Deny  = New-Object System.Management.Automation.Host.ChoiceDescription '&Deny',  'Do not allow loading of the new profile'
                $Allow = New-Object System.Management.Automation.Host.ChoiceDescription '&Allow', 'Allow loading of the new profile'
                $Choices = [System.Management.Automation.Host.ChoiceDescription[]]($Deny, $Allow)
                $Prompt = 'Do you wish to allow loading the changed profile?'
                $Result = $Host.UI.PromptForChoice($null, $Prompt, $Choices, 0)

                if ($Result -eq 1) {
                    Ensure-Directory -Path $localProfilePath
                    
                    # Write to temp file first, then move atomically for safety
                    $tempFile = "$localProfilePath.tmp"
                    Set-Content -Path $tempFile -Value $repoProfileContent -Encoding UTF8 -Force
                    Move-Item -Path $tempFile -Destination $localProfilePath -Force
                    
                    Log-Message "Profile updated from repository file."

                    $versionData.LastModified = $lastModified
                    $versionData.LastCommitHash = $lastCommitHash
                    $versionData.LastBlobSha = $remoteBlobSha
                    
                    # Write version file atomically as well
                    $tempVersionFile = "$versionFile.tmp"
                    ($versionData | ConvertTo-Json -Depth 5) | Set-Content -Path $tempVersionFile -Force -Encoding UTF8
                    Move-Item -Path $tempVersionFile -Destination $versionFile -Force
                    
                    Write-Host "Profile updated successfully. Please restart your PowerShell session to load the new profile." -ForegroundColor Green
                } else {
                    Log-Message "Profile update denied by user."
                }
            } else {
                Log-Message "No update needed."
            }

            Set-Content -Path $updateCheckFile -Value (Get-Date -Format "yyyy-MM-dd HH:mm:ss").Trim() -Encoding UTF8 -Force
            $env:PROFILE_LAST_CHECK = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        } catch {
            Log-Message "Error during update check: $($_.Exception.Message)"
            # Suppress to avoid interfering with shell startup
        }
    }
}

# Check for updates on shell startup
Check-ForUpdates -force:$false

# Function to force an update check manually
function Force-UpdateCheck {
    Check-ForUpdates -force:$true
}

# --- Customization ------------------------------------------------------------

# Import WinGet CommandNotFound module if available (skip if missing)
try {
    if (Get-Module -ListAvailable -Name Microsoft.WinGet.CommandNotFound) {
        Import-Module -Name Microsoft.WinGet.CommandNotFound -ErrorAction SilentlyContinue
    } else {
        Log-Message "Module 'Microsoft.WinGet.CommandNotFound' not found; skipping import."
    }
} catch {
    Log-Message "Failed to import module 'Microsoft.WinGet.CommandNotFound': $($_.Exception.Message)"
}

# Import z if available (skip if missing)
try {
    if (Get-Module -ListAvailable -Name z) {
        Import-Module z -ErrorAction SilentlyContinue
    } else {
        Log-Message "Module 'z' not found; skipping import."
    }
} catch {
    Log-Message "Failed to import module 'z': $($_.Exception.Message)"
}

# Initialize oh-my-posh if installed (skip if missing)
try {
    if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
        oh-my-posh init pwsh --config 'https://raw.githubusercontent.com/BenjaminMichaelis/Config/main/benjaminmichaelis.omp.json' | Invoke-Expression
    } else {
        Log-Message "oh-my-posh not found; skipping prompt initialization."
    }
} catch {
    Log-Message "Failed to initialize oh-my-posh: $($_.Exception.Message)"
}

# --- Custom Aliases -----------------------------------------------------------
function ConvertTo-Base64 {
    param ([string]$InputString)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($InputString)
    [System.Convert]::ToBase64String($bytes)
}
Set-Alias StringToBase64 ConvertTo-Base64

function ConvertFrom-Base64 {
    param ([string]$Base64String)
    $bytes = [System.Convert]::FromBase64String($Base64String)
    [System.Text.Encoding]::UTF8.GetString($bytes)
}
Set-Alias Base64ToString ConvertFrom-Base64

# --- Image Compression --------------------------------------------------------
# Load System.Drawing once if possible
try {
    $loadedAssemblies = [AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object { $_.GetName().Name }
    if ('System.Drawing' -notin $loadedAssemblies) {
        Add-Type -AssemblyName System.Drawing
    }
} catch {
    Log-Message "System.Drawing unavailable: $($_.Exception.Message)"
}

# Compress images in a folder
function Compress-Jpg-In-Folder {
    param (
        [Parameter(Mandatory)][string]$folderPath,
        [string]$outputFolderPath = (Join-Path $folderPath 'compress'),
        [int]$compressionQuality = 60
    )

    if (-not (Test-Path -LiteralPath $folderPath)) {
        Write-Host "Folder not found: $folderPath" -ForegroundColor Yellow
        return
    }

    if (-not (Test-Path -LiteralPath $outputFolderPath)) {
        New-Item -ItemType Directory -Path $outputFolderPath | Out-Null
    }

    # Reliable extension filtering without relying on -Include quirks
    $imageFiles = Get-ChildItem -Path $folderPath -File | Where-Object {
        $_.Extension -match '^\.(jpg|jpeg|png)$'
    }

    if ($imageFiles.Count -eq 0) {
        Write-Host "No image files found in folder." -ForegroundColor Yellow
        return
    }

    foreach ($file in $imageFiles) {
        $outName = Join-Path $outputFolderPath ("{0}_compressed{1}" -f [System.IO.Path]::GetFileNameWithoutExtension($file.Name), $file.Extension)
        Compress-Image -filePath $file.FullName -compressionQuality $compressionQuality -outputFileName $outName
    }
}
Set-Alias CompressFolder Compress-Jpg-In-Folder

function Compress-Image {
    param (
        [Parameter(Mandatory)][string]$filePath,
        [int]$compressionQuality = 60,
        [string]$outputFileName = ""
    )

    if (-not (Test-Path -LiteralPath $filePath)) {
        Write-Host "File not found: $filePath" -ForegroundColor Yellow
        return
    }

    $fileExtension = [System.IO.Path]::GetExtension($filePath)
    if ([string]::IsNullOrWhiteSpace($outputFileName)) {
        $outputFileName = Join-Path -Path (Split-Path -Path $filePath -Parent) -ChildPath (
            [System.IO.Path]::GetFileNameWithoutExtension($filePath) + "_compressed" + $fileExtension
        )
    } else {
        Ensure-Directory -Path $outputFileName
    }

    Write-Host "Compressing $filePath -> $outputFileName ..."

    try {
        $image = [System.Drawing.Image]::FromFile($filePath)
        try {
            $encoderParams = New-Object System.Drawing.Imaging.EncoderParameters
            $encoder = [System.Drawing.Imaging.Encoder]::Quality
            $encoderParam = New-Object System.Drawing.Imaging.EncoderParameter($encoder, [long]$compressionQuality)
            $encoderParams.Param[0] = $encoderParam

            if ($fileExtension -match '^\.(jpg|jpeg)$') {
                $jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
                $image.Save($outputFileName, $jpegCodec, $encoderParams)
                Write-Host "Compression complete." -ForegroundColor Green
            } elseif ($fileExtension -ieq ".png") {
                # Note: GDI+ quality parameter doesn't truly optimize PNGs
                # Consider using external tools like pngquant or optipng for better PNG compression
                $pngCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/png" }
                $image.Save($outputFileName, $pngCodec, $encoderParams)
                Write-Host "Compression complete (Note: PNG compression via GDI+ is limited)." -ForegroundColor Yellow
            } else {
                Write-Host "Unsupported format: $fileExtension" -ForegroundColor Yellow
            }
        } finally {
            $image.Dispose()
        }
    } catch {
        Write-Host ("Failed to compress {0}: {1}" -f $filePath, $_.Exception.Message) -ForegroundColor Red
        Log-Message ("Image compression failed for {0}: {1}" -f $filePath, $_.Exception.Message)
    }
}
Set-Alias CompressSingle Compress-Image

# --- Help --------------------------------------------------------------------
function Show-MyHelp {
    Write-Host "`nMy Custom Aliases and Functions:" -ForegroundColor Cyan
    Write-Host "==============================`n" -ForegroundColor Cyan
    
    Write-Host "Aliases:" -ForegroundColor Yellow
    $customAliases = @('StringToBase64', 'Base64ToString', 'CompressFolder', 'CompressSingle', 'MyHelp')
    Get-Alias | Where-Object { $_.Name -in $customAliases } | ForEach-Object {
        Write-Host "  $($_.Name) -> $($_.Definition)" -ForegroundColor White
    }
    
    Write-Host "`nFunctions:" -ForegroundColor Yellow
    $customFunctions = @(
        'ConvertTo-Base64', 'ConvertFrom-Base64', 
        'Compress-Jpg-In-Folder', 'Compress-Image',
        'Force-UpdateCheck', 'Show-MyHelp'
    )
    Get-Command -CommandType Function | Where-Object { $_.Name -in $customFunctions } | ForEach-Object {
        Write-Host "  $($_.Name)" -ForegroundColor White
        $params = (Get-Command $_.Name).Parameters.Values
        if ($params.Count -gt 0) {
            Write-Host "    Parameters:" -ForegroundColor Gray
            foreach ($param in $params) {
                $mandatory = if ($param.Attributes.Mandatory) { " [Required]" } else { "" }
                Write-Host "      - $($param.Name): $($param.ParameterType.Name)$mandatory" -ForegroundColor Gray
            }
        }
        Write-Host ""
    }
}
Set-Alias MyHelp Show-MyHelp

# https://code.visualstudio.com/docs/terminal/shell-integration
if ($env:TERM_PROGRAM -eq "vscode") { . "$(code --locate-shell-integration-path pwsh)" }

# Show welcome message
Write-Host "`nPowerShell profile loaded. Type 'MyHelp' for available custom commands.`n" -ForegroundColor Green
