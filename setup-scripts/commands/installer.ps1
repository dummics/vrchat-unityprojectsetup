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
    $defaultsPath = Join-Path $scriptDir "config\\vrcsetup.defaults"
    [void](Initialize-ConfigIfMissing -ConfigPath $configPath -DefaultsPath $defaultsPath)

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

            # 1) Ensure Unity Test Framework + any required manifest tweaks BEFORE importing the big UnityPackage.
            Install-NUnitPackage -ProjectPath $newProjectPath -Test:$Test

            # 2) Install configured VPM packages BEFORE importing the UnityPackage(s).
            # This usually reduces re-import work when the GUI opens (SDK + dependencies already present).
            Install-PackagesInProject -ProjectPath $newProjectPath -Packages $VPM_PACKAGES -Test:$Test | Out-Null

            $packagesToImport = @($projectPath)

            $mainPackageResolved = $projectPath
            try { $mainPackageResolved = (Resolve-Path $projectPath -ErrorAction Stop).Path } catch { }

            $workspaceRoot = (Resolve-Path (Join-Path $scriptDir '..\..')).Path
            $commonPackagesPath = $null
            if ($config -and ($config.PSObject.Properties.Name -contains 'UnityPackagesFolder')) {
                $cfgCommon = [string]$config.UnityPackagesFolder
                if (-not [string]::IsNullOrWhiteSpace($cfgCommon)) {
                    $cfgCommon = $cfgCommon.Trim().Trim('"').Trim("'")
                    if ([System.IO.Path]::IsPathRooted($cfgCommon)) {
                        $commonPackagesPath = $cfgCommon
                    } else {
                        $commonPackagesPath = Join-Path $workspaceRoot $cfgCommon
                    }
                }
            }

            if ($commonPackagesPath -and (Test-Path $commonPackagesPath)) {
                $commonPackages = Get-ChildItem -Path $commonPackagesPath -Filter "*.unitypackage" -ErrorAction SilentlyContinue
                foreach ($pkg in $commonPackages) {
                    $pkgResolved = $pkg.FullName
                    try { $pkgResolved = (Resolve-Path $pkg.FullName -ErrorAction Stop).Path } catch { }
                    if ($pkgResolved -ne $mainPackageResolved) {
                        $packagesToImport += $pkg.FullName
                    }
                }
            }

            # 3) Import UnityPackage(s) at the end.
            # Importing multiple packages in one Unity invocation can be flaky; do it sequentially to guarantee order.
            $extraPackages = @()
            if ($packagesToImport.Count -gt 1) {
                $extraPackages = @($packagesToImport | Select-Object -Skip 1)
            }

            Write-Host ("Importing UnityPackage(s)... (main=1, extra={0})" -f $extraPackages.Count) -ForegroundColor Cyan

            # Main package first
            $importLogFile = Join-Path $env:TEMP "unity-import-main-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
            $importArgs = @(
                "-projectPath", "`"${newProjectPath}`"",
                "-importPackage", "`"$($packagesToImport[0])`"",
                "-quit",
                "-batchmode",
                "-logFile", "`"${importLogFile}`""
            )
            $importProcess = Start-Process -FilePath $UNITY_EDITOR_PATH -ArgumentList $importArgs -NoNewWindow -PassThru
            Show-ProcessProgress -Process $importProcess -LogFile $importLogFile -Prefix "[Import:main]" | Out-Null

            # Extra packages (if any) AFTER main
            $idx = 0
            foreach ($pkg in $extraPackages) {
                $idx++
                $extraLog = Join-Path $env:TEMP ("unity-import-extra{0:00}-{1}.log" -f $idx, (Get-Date -Format 'yyyyMMdd-HHmmss'))
                $extraArgs = @(
                    "-projectPath", "`"${newProjectPath}`"",
                    "-importPackage", "`"${pkg}`"",
                    "-quit",
                    "-batchmode",
                    "-logFile", "`"${extraLog}`""
                )
                $p = Start-Process -FilePath $UNITY_EDITOR_PATH -ArgumentList $extraArgs -NoNewWindow -PassThru
                Show-ProcessProgress -Process $p -LogFile $extraLog -Prefix ("[Import:extra {0}/{1}]" -f $idx, $extraPackages.Count) | Out-Null
            }

            # 4) Post-import settle pass (bounded) to let Unity finish asset pipeline work.
            # This helps avoid a full re-import/crunch pass when opening the GUI right after.
            try {
                $editorDir = Join-Path $newProjectPath "Assets\\Editor"
                if (-not (Test-Path $editorDir)) { New-Item -Path $editorDir -ItemType Directory -Force | Out-Null }

                $postImportScriptPath = Join-Path $editorDir "VrcSetupPostImport.cs"
                @'
using UnityEditor;
using UnityEngine;

public static class VrcSetupPostImport
{
    // Called via -executeMethod VrcSetupPostImport.Run
    public static void Run()
    {
        double start = EditorApplication.timeSinceStartup;
        double lastBusy = start;
        const double stableSeconds = 2.0;
        const double timeoutSeconds = 600.0; // 10 minutes max

        Debug.Log("[vrc-setup] Post-import settle started...");
        AssetDatabase.Refresh();

        EditorApplication.update += () =>
        {
            bool busy = EditorApplication.isCompiling || EditorApplication.isUpdating;
            if (busy) lastBusy = EditorApplication.timeSinceStartup;

            double now = EditorApplication.timeSinceStartup;
            if (!busy && (now - lastBusy) >= stableSeconds)
            {
                Debug.Log("[vrc-setup] Post-import settle complete, saving assets and quitting.");
                AssetDatabase.SaveAssets();
                EditorApplication.Exit(0);
            }

            if ((now - start) >= timeoutSeconds)
            {
                Debug.LogWarning("[vrc-setup] Post-import settle TIMEOUT, saving assets and quitting anyway.");
                AssetDatabase.SaveAssets();
                EditorApplication.Exit(0);
            }
        };
    }
}
'@ | Set-Content -Path $postImportScriptPath -Encoding UTF8

                $settleLogFile = Join-Path $env:TEMP "unity-postimport-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
                $settleArgs = @(
                    "-projectPath", "`"${newProjectPath}`"",
                    "-executeMethod", "VrcSetupPostImport.Run",
                    "-quit",
                    "-batchmode",
                    "-logFile", "`"${settleLogFile}`""
                )

                Write-Host "Finalizing import (post-import settle)..." -ForegroundColor Cyan
                $settleProcess = Start-Process -FilePath $UNITY_EDITOR_PATH -ArgumentList $settleArgs -NoNewWindow -PassThru
                Show-ProcessProgress -Process $settleProcess -LogFile $settleLogFile -Prefix "[Finalize]" | Out-Null
            } catch {
                Write-Host "Warning: post-import finalize step failed: ${_}" -ForegroundColor Yellow
            }

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


