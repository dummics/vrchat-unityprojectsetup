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
        $Packages,
        [switch]$Test
    )

    Push-Location $ProjectPath
    try {

    $manifestBackedUp = $false
    foreach ($pkg in $Packages.PSObject.Properties) {
        $packageName = $pkg.Name
        $packageVersion = $pkg.Value

        Write-Host "Processing package: ${packageName} : ${packageVersion}" -ForegroundColor Cyan
        # Backup manifest before changes
        $manifestPath = Join-Path $ProjectPath "Packages\manifest.json"
        if ((-not $Test) -and (Test-Path $manifestPath) -and (-not $manifestBackedUp)) {
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

    if ($Test) {
        Write-Host "[TEST] Would resolve VPM project: ${ProjectPath}" -ForegroundColor DarkGray
        Add-Content -Path $global:VRCSETUP_LOGFILE -Value "[TEST] Would resolve VPM project: ${ProjectPath}"
        return 0
    }

    # Resolve packages
    $manifestPath = Join-Path ${ProjectPath} "Packages\manifest.json"
    vpm resolve project ${ProjectPath} 2>&1 | Tee-Object -FilePath $global:VRCSETUP_LOGFILE -Append

    return 0

    } finally {
        Pop-Location
    }
}

function Start-Installer {
    param(
        [string]$projectPath,
        [switch]$Test,
        [string]$NewProjectName
    )

    # prepare environment
    $logDir = Join-Path $scriptDir 'logs'
    if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
    $global:VRCSETUP_LOGFILE = Join-Path $logDir "vrcsetup-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
    $configPath = Join-Path $scriptDir "config\\vrcsetup.json"

    # Normalize path input (drag&drop often wraps in quotes)
    if ($null -ne $projectPath) {
        $projectPath = $projectPath.Trim()
        $projectPath = $projectPath.Trim('"')
        $projectPath = $projectPath.Trim("'")
    }

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
        return 1
    }

    # Normalize legacy formats (array -> object with versions)
    if ($VPM_PACKAGES -is [System.Array]) {
        $normalized = [ordered]@{}
        foreach ($pkg in $VPM_PACKAGES) {
            if (-not [string]::IsNullOrWhiteSpace($pkg)) {
                $normalized[$pkg] = "latest"
            }
        }
        $VPM_PACKAGES = [pscustomobject]$normalized
    }

    if (-not $VPM_PACKAGES) {
        Write-Host "Error: VpmPackages missing in config." -ForegroundColor Red
        return 1
    }

    # UnityPackage mode: create a new project, import package(s), then continue install on the new project
    if ($projectPath -like "*.unitypackage") {
        Write-Host "Detected UnityPackage: creating new project..." -ForegroundColor Cyan

        $packageName = [System.IO.Path]::GetFileNameWithoutExtension($projectPath)
        $projectName = if (-not [string]::IsNullOrWhiteSpace($NewProjectName)) { $NewProjectName } else { $packageName }
        if (-not $UNITY_PROJECTS_ROOT) {
            Write-Host "Error: UnityProjectsRoot is missing in config." -ForegroundColor Red
            return 1
        }

        $newProjectPath = Join-Path $UNITY_PROJECTS_ROOT $projectName
        if (Test-Path $newProjectPath) {
            Write-Host "Error: project already exists at: ${newProjectPath}" -ForegroundColor Red
            return 1
        }

        if (-not $UNITY_EDITOR_PATH -or (-not (Test-Path $UNITY_EDITOR_PATH))) {
            Write-Host "Error: Unity Editor not found at: ${UNITY_EDITOR_PATH}" -ForegroundColor Red
            return 1
        }

        if ($Test) {
            Write-Host "[TEST] Would create Unity project: ${newProjectPath}" -ForegroundColor DarkGray
            Write-Host "[TEST] Would import UnityPackage: ${projectPath}" -ForegroundColor DarkGray
            Write-Host "[TEST] Would then install configured VPM packages into: ${newProjectPath}" -ForegroundColor DarkGray
            return 0
        } else {
            Write-Host "Creating project: ${projectName}" -ForegroundColor Green
            Write-Host "Path: ${newProjectPath}" -ForegroundColor Gray

            $createLogFile = Join-Path $env:TEMP "unity-create-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
            $createArgs = "-createProject `"${newProjectPath}`" -quit -batchmode -logFile `"${createLogFile}`""
            $createProcess = Start-Process -FilePath $UNITY_EDITOR_PATH -ArgumentList $createArgs -NoNewWindow -PassThru
            Show-ProcessProgress -Process $createProcess -LogFile $createLogFile -Prefix "[Unity]" | Out-Null

            if (-not (Test-Path (Join-Path $newProjectPath "Assets"))) {
                Write-Host "Error: project was not created correctly." -ForegroundColor Red
                if (Test-Path $createLogFile) {
                    Write-Host "Last log lines:" -ForegroundColor Yellow
                    Get-Content $createLogFile -Tail 20
                }
                Remove-Item -Path $newProjectPath -Recurse -Force -ErrorAction SilentlyContinue
                return 1
            }

            $packagesToImport = @($projectPath)

            $workspaceRoot = (Resolve-Path (Join-Path $scriptDir '..\..')).Path
            $commonPackagesPath = Join-Path $workspaceRoot "_unitypackages"
            if (Test-Path $commonPackagesPath) {
                $commonPackages = Get-ChildItem -Path $commonPackagesPath -Filter "*.unitypackage" -ErrorAction SilentlyContinue
                foreach ($pkg in $commonPackages) {
                    if ($pkg.FullName -ne $projectPath) {
                        $packagesToImport += $pkg.FullName
                    }
                }
            }

            $importLogFile = Join-Path $env:TEMP "unity-import-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
            $importArgs = @(
                "-projectPath", "`"${newProjectPath}`""
            )
            foreach ($pkg in $packagesToImport) {
                $importArgs += "-importPackage"
                $importArgs += "`"${pkg}`""
            }
            $importArgs += "-quit"
            $importArgs += "-batchmode"
            $importArgs += "-logFile"
            $importArgs += "`"${importLogFile}`""

            Write-Host "Importing UnityPackage(s)..." -ForegroundColor Cyan
            $importProcess = Start-Process -FilePath $UNITY_EDITOR_PATH -ArgumentList $importArgs -NoNewWindow -PassThru
            Show-ProcessProgress -Process $importProcess -LogFile $importLogFile -Prefix "[Import]" | Out-Null

            Install-NUnitPackage -ProjectPath $newProjectPath -Test:$Test

            $projectPath = $newProjectPath
        }
    }

    # If not a Unity package, assume existing project and install packages
    $assetsPath = Join-Path $projectPath "Assets"
    $packagesPath = Join-Path $projectPath "Packages"
    if ((Test-Path $assetsPath) -or (Test-Path $packagesPath)) {
        Install-PackagesInProject -ProjectPath $projectPath -Packages $VPM_PACKAGES -Test:$Test | Out-Null
        return 0
    }

    Write-Host "Error: path is not a Unity project (missing Assets/Packages): ${projectPath}" -ForegroundColor Red
    return 1

    # If we reach here nothing else to do
    return 0
}


