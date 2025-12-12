param()

# commands/installer.ps1 - central installer logic exported as a function
$cmdDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptDir = (Resolve-Path (Join-Path $cmdDir '..')).Path
. "$scriptDir\lib\menu.ps1"
. "$scriptDir\lib\utils.ps1"
. "$scriptDir\lib\progress.ps1"
. "$scriptDir\lib\config.ps1"

function Install-PackagesInProject {
    param(
        [string]$ProjectPath,
        [hashtable]$Packages,
        [switch]$Test
    )

    $manifestBackedUp = $false
    foreach ($pkg in $Packages.PSObject.Properties) {
        $packageName = $pkg.Name
        $packageVersion = $pkg.Value

        Write-Host "Processing package: ${packageName} : ${packageVersion}" -ForegroundColor Cyan
        # Backup manifest before changes
        $manifestPath = Join-Path $ProjectPath "Packages\manifest.json"
        if ((Test-Path $manifestPath) -and (-not $manifestBackedUp)) {
            try {
                $backupPath = "${manifestPath}.bak.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                Copy-Item $manifestPath -Destination $backupPath -Force
                Write-Host "Backup manifest created: ${backupPath}" -ForegroundColor Gray
                $manifestBackedUp = $true
            } catch {
                Write-Host "Failed to create manifest backup: ${_}" -ForegroundColor Yellow
            }
        }

        if ($Test) {
            Write-Host "[TEST] Would add package: ${packageName}@${packageVersion}" -ForegroundColor DarkGray
            Add-Content -Path $global:VRCSETUP_LOGFILE -Value "[TEST] Would add package: ${packageName}@${packageVersion}"
            continue
        }

        try {
            if ($packageVersion -eq "latest") {
                Write-Host "Adding package: ${packageName} (latest)" -ForegroundColor Cyan
                vpm add package "${packageName}" 2>&1 | Tee-Object -FilePath $global:VRCSETUP_LOGFILE -Append
            } else {
                Write-Host "Adding package: ${packageName} @ ${packageVersion}" -ForegroundColor Cyan
                vpm add package "${packageName}@${packageVersion}" 2>&1 | Tee-Object -FilePath $global:VRCSETUP_LOGFILE -Append
            }
            if ($LASTEXITCODE -ne 0) { Write-Host "vpm reported exit code ${LASTEXITCODE} for ${packageName}" -ForegroundColor Yellow }
        } catch {
            Write-Host "Failed to add ${packageName}: ${_}" -ForegroundColor Red
            Add-Content -Path $global:VRCSETUP_LOGFILE -Value "ERROR: Failed to add ${packageName} : ${_}"
        }
    }

    # Resolve packages to ensure lock file snapshot
    $manifestPath = Join-Path ${ProjectPath} "Packages\manifest.json"
    vpm resolve project ${ProjectPath} 2>&1 | Tee-Object -FilePath $global:VRCSETUP_LOGFILE -Append

    return 0
}

function Start-Installer {
    param([string]$projectPath, [switch]$Test)

    # prepare environment
    $logDir = Join-Path $scriptDir 'logs'
    if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
    $global:VRCSETUP_LOGFILE = Join-Path $logDir "vrcsetup-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
    $configPath = Join-Path $scriptDir "config\\vrcsetup.json"

    # If reset requested
    if ($projectPath -eq "-reset") {
        if (Test-Path $configPath) { Remove-Item $configPath -Force; Write-Host "Configuration reset" -ForegroundColor Green; return 0 }
        Write-Host "No configuration to reset" -ForegroundColor Yellow
        return 0
    }

    # Validate projectPath exists
    if (-not $projectPath) { Write-Host "Error: project path required" -ForegroundColor Red; return 1 }
    if (-not (Test-Path $projectPath)) { Write-Host "Error: path not found: ${projectPath}" -ForegroundColor Red; return 1 }

    # Load config
    $config = Load-Config -ConfigPath $configPath
    if ($config) {
        $UNITY_PROJECTS_ROOT = $config.UnityProjectsRoot
        $UNITY_EDITOR_PATH = $config.UnityEditorPath
        $VPM_PACKAGES = $config.VpmPackages
    } else {
        Write-Host "Config missing (create via the wizard)." -ForegroundColor Red
    }

    # If not a Unity package, assume existing project and install packages
    $assetsPath = Join-Path $projectPath "Assets"
    $packagesPath = Join-Path $projectPath "Packages"
    if (Test-Path $assetsPath -or Test-Path $packagesPath) {
        Install-PackagesInProject -ProjectPath $projectPath -Packages $VPM_PACKAGES -Test:$Test | Out-Null
        return 0
    }

    # If we reach here nothing else to do
    return 0
}

Export-ModuleMember -Function Start-Installer
