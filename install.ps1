if((Get-ExecutionPolicy) -eq 'Restricted') {
  Set-ExecutionPolicy Bypass -Scope Process -Force
}

#Install Chocolatey
if(-not (Get-Command choco -ErrorAction Ignore)) {
  [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; 
  Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}

#Install Scoop
if(-not (Get-Command scoop -ErrorAction Ignore)) {
  Invoke-WebRequest -useb get.scoop.sh | Invoke-Expression
}


function Add-ScoopBucket {
  [CmdletBinging()]
  param(
    [string]$name,
    [string]$url
  )

  # Git is required when adding an additional scoop bucket.
  if(-not (Get-Command git -ErrorAction Ignore)) {
    choco install git -y /GitOnlyOnPath /NoAutoCrlf
  }}

  if((scoop bucket list) -notcontains $name) {
    scoop bucket add $name $url 
  }
  else {
    Write-Information -MessageData "Scoopbucket $name is already added."
  }
}
Add-ScoopBucket -Name 'MarkMichaelis' -Url 'https://github.com/MarkMichaelis/ScoopBucket.git'
