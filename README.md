# Config Files

## Git Hooks

Strips AI-generated trailers (e.g. `Co-authored-by: Copilot`) from commit messages automatically.

**macOS / Linux:**

```bash
bash git-hooks/install.sh
```

**Windows (PowerShell):**

```powershell
powershell -ExecutionPolicy Bypass -File git-hooks/install.ps1
```

## Winget Config instructions

1. Take the desired configuration scripts from the [winget_configurations folder](./winget_configurations)
2. Follow the instructions at [https://learn.microsoft.com/windows/package-manager/configuration/](https://learn.microsoft.com/windows/package-manager/configuration/?WT.mc_id=8B97120A00B57354#use-a-winget-configuration-file-to-configure-your-machine) to setup your machine

## Running install.ps1

On a fresh Windows machine the default execution policy is **Restricted**, which prevents PowerShell from running `.ps1` scripts entirely. The in-script execution-policy check (`Set-ExecutionPolicy Bypass -Scope Process`) is a safety notice only — it cannot bootstrap itself from Restricted mode because the script never gets to execute.

To launch the installer, run:

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1
```

## Scoop Bucket instructions:

Setups my personal scoop bucket. Installs and uninstalls programs.

Runs via: `scoop bucket add BenjaminMichaelis https://github.com/BenjaminMichaelis/ScoopBucket.git`

Main Command for a new computer: `ClientBasePackages`
Command for Development tools: `DeveloperBasePackages`
