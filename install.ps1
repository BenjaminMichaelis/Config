if ((Get-ExecutionPolicy) -eq 'Restricted') {
  Set-ExecutionPolicy Bypass -Scope Process -Force
}

#Install Chocolatey
if (-not (Get-Command choco -ErrorAction Ignore)) {
  [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; 
  Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}

#Install Scoop
if (-not (Get-Command scoop -ErrorAction Ignore)) {
  $env:SCOOP = "$env:ProgramData\scoop"
  [environment]::SetEnvironmentVariable('SCOOP', $env:SCOOP, 'Machine')
  Invoke-WebRequest -UseBasicParsing get.scoop.sh | Invoke-Expression
}


function Add-ScoopBucket {
  [CmdletBinding()]
  param(
    [string]$name,
    [string]$url
  )

  # Git is required when adding an additional scoop bucket.
  if (-not (Get-Command git -ErrorAction Ignore)) {
    choco install git -y --params "/GitOnlyOnPath /NoAutoCrlf /NoShellHereIntegration"
    # Set-Alias -Name git -Value "$env:ProgramFiles\Git\cmd\git.exe"
    $env:Path = "$env:Path;$env:ProgramFiles\Git\cmd\"
  } 

  if ((scoop bucket list) -notcontains $name) {
    Write-Host "scoop bucket add $name $url"
    # Run in new PowerShell process to ensure git path is enabled.
    # powershell -ExecutionPolicy unrestricted -Command scoop bucket add $name $url
    scoop bucket add $name $url
  }
  else {
    Write-Information -MessageData "Scoopbucket $name is already added."
  }
}
Add-ScoopBucket -Name 'MarkMichaelis' -Url 'https://github.com/MarkMichaelis/ScoopBucket'
