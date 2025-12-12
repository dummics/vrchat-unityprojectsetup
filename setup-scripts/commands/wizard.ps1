# VRChat Setup Wizard (commands/wizard.ps1) - modularized
# This file is a drop-in for vrcsetup-wizard.ps1. It contains the full wizard logic.

param()

# === CARICAMENTO CONFIG & HELPERS ===
$cmdDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptDir = (Resolve-Path (Join-Path $cmdDir '..')).Path
. "${scriptDir}\lib\menu.ps1"
. "${scriptDir}\lib\utils.ps1"
. "${scriptDir}\lib\config.ps1"
. "${scriptDir}\commands\installer.ps1"
$configPath = Join-Path $scriptDir "config\\vrcsetup.json"

# Main installer function is provided by commands\installer.ps1 (Start-Installer)

# --- FUNCTIONS ---
function Initialize-VpmTestProject {
    param([string]$ScriptDir)
    $testProjectPath = Join-Path $ScriptDir ".vpm-validation-cache"
    if (Test-Path ${testProjectPath}) {
        return $testProjectPath
    }
    Write-Host "Inizializzazione cache validazione VPM (solo prima volta)..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $testProjectPath -Force | Out-Null
    $packagesPath = Join-Path $testProjectPath "Packages"
    New-Item -ItemType Directory -Path $packagesPath -Force | Out-Null
    $manifest = @{ dependencies = @{ } }
    $manifest | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $packagesPath "manifest.json") -Encoding UTF8
    $vpmManifest = @{ dependencies = @{ }; locked = @{ } }
    $vpmManifest | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $packagesPath "vpm-manifest.json") -Encoding UTF8
    Write-Host "Cache creata in: ${testProjectPath}" -ForegroundColor Green
    return $testProjectPath
}

function Test-VpmPackageVersion {
    param([string]$PackageName, [string]$Version, [string]$ScriptDir)
    if ($Version -eq "latest") { return @{ Valid = $true; Message = "Versione 'latest' sempre valida" } }
    Write-Host "Validazione ${PackageName}@${Version}..." -ForegroundColor Gray
    $testProject = Initialize-VpmTestProject -ScriptDir $ScriptDir
    try {
        $packageSpec = "${PackageName}@${Version}"
        $output = vpm add package $packageSpec -p $testProject 2>&1 | Out-String
        if ($output -match "ERR.*Could not get match" -or $output -match "ERR.*not found") {
            $reposPath = "${env:LOCALAPPDATA}\VRChatCreatorCompanion\Repos"
            $availableVersions = @()
            if (Test-Path $reposPath) {
                Get-ChildItem $reposPath -Filter "*.json" -ErrorAction SilentlyContinue | ForEach-Object {
                    try {
                        $repoData = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
                        if (${repoData.packages}.${PackageName}) {
                            $versions = $repoData.packages.$PackageName.versions.PSObject.Properties.Name
                            if ($versions) { $availableVersions += $versions }
                        }
                    } catch { }
                }
            }
            if ($availableVersions.Count -gt 0) {
                $sortedVersions = $availableVersions | Sort-Object -Descending | Select-Object -First 5
                $versionList = $sortedVersions -join ", "
                return @{ Valid = $false; Message = "Versione ${Version} non trovata. Ultime disponibili: ${versionList}" }
            }
            return @{ Valid = $false; Message = "Versione ${Version} non disponibile" }
        }
        Write-Host "Versione valida!" -ForegroundColor Green
        vpm remove package $PackageName -p $testProject 2>&1 | Out-Null
        return @{ Valid = $true; Message = "Versione verificata con VPM" }
    } catch {
        Write-Host "Errore durante validazione: ${_}" -ForegroundColor Red
        return @{ Valid = $false; Message = "Errore durante validazione VPM" }
    }
}

# --- Main launcher for interactive wizard ---
function Start-Wizard {
    # Header
    Write-Host "`n================================" -ForegroundColor Cyan
    Write-Host "   VRChat Project Setup Wizard" -ForegroundColor Cyan
    Write-Host "================================`n" -ForegroundColor Cyan

    # Verify main installer exists
    if (-not (Test-Path $vrcsetupScript)) {
        Write-Host "Error: main installer (${vrcsetupScript}) not found" -ForegroundColor Red
        Read-Host "Press ENTER to exit"
        exit 1
    }

    # Menu loop (copied from original wizard)
    while ($true) {
        Clear-Host
        Write-Host "`nWhat do you want to do?" -ForegroundColor Yellow
        Write-Host "  1) Create new project from UnityPackage" -ForegroundColor White
        Write-Host "  2) Setup VRChat on existing project" -ForegroundColor White
        Write-Host "  3) Configure VPM packages" -ForegroundColor White
        Write-Host "  4) Reset configuration" -ForegroundColor White
        Write-Host "  5) Exit" -ForegroundColor White
        Write-Host ""

        $choice = Read-Host "Choice [1-5]"
        if ([string]::IsNullOrWhiteSpace($choice)) { continue }

        switch ($choice) {
            "1" {
                Clear-Host
                Write-Host "`n--- Create new project from UnityPackage ---" -ForegroundColor Cyan
                Write-Host "Drag here the .unitypackage file (or paste the full path):" -ForegroundColor Yellow
                Write-Host "(Press ENTER to cancel)" -ForegroundColor Gray
                $packagePath = Read-Host "Path UnityPackage"
                    Start-Installer -projectPath $packagePath
                $packagePath = $packagePath.Trim('"')
                if (-not (Test-Path $packagePath)) { Write-Host "`nError: file not found!" -ForegroundColor Red; Read-Host "Press ENTER to continue"; Clear-Host; continue }
                if ($packagePath -notlike "*.unitypackage") { Write-Host "`nError: the file must be a .unitypackage!" -ForegroundColor Red; Read-Host "Press ENTER to continue"; Clear-Host; continue }
                Write-Host "`nStarting project creation..." -ForegroundColor Green
                Start-Installer -projectPath $packagePath
                Write-Host "`n--- Operation completed ---" -ForegroundColor Green
                Read-Host "Press ENTER to return to the menu"; Clear-Host
            }

            "2" {
                Clear-Host
                Write-Host "`n--- Setup VRChat on existing project ---" -ForegroundColor Cyan
                Write-Host "Drag here the Unity project folder (or paste the path):" -ForegroundColor Yellow
                Write-Host "(Press ENTER to cancel)" -ForegroundColor Gray
                $projectPath = Read-Host "Project Path"
                if ([string]::IsNullOrWhiteSpace($projectPath)) { Write-Host "Operation canceled." -ForegroundColor Yellow; Start-Sleep -Seconds 1; continue }
                    Start-Installer -projectPath $projectPath
                if (-not (Test-Path $projectPath)) { Write-Host "`nError: folder not found!" -ForegroundColor Red; Read-Host "Press ENTER to continue"; Clear-Host; continue }
                $assetsPath = Join-Path $projectPath "Assets"
                if (-not (Test-Path $assetsPath)) { Write-Host "`nError: not a Unity project (missing Assets)!" -ForegroundColor Red; Read-Host "Press ENTER to continue"; Clear-Host; continue }
                Write-Host "`nStarting VRChat setup..." -ForegroundColor Green
                Start-Installer -projectPath $projectPath
                Write-Host "`n--- Operation completed ---" -ForegroundColor Green
                Read-Host "Press ENTER to return to the menu"; Clear-Host
            }

            "3" {
                # Config VPM packages
                        Start-Installer -projectPath "-reset"; Read-Host "Press ENTER to continue"
                if (-not (Test-Path $configPath)) { Write-Host "`nError: initialize a project first to create the configuration!" -ForegroundColor Red; Read-Host "Press ENTER to continue"; Clear-Host; continue }
                $config = Load-Config -ConfigPath $configPath
                if ($config.VpmPackages -is [System.Array]) { $newPackages = @{}; foreach ($pkg in $config.VpmPackages) { $newPackages[$pkg] = "latest" }; $config.VpmPackages = $newPackages }
                if (-not $config.VpmPackages) { $config | Add-Member -MemberType NoteProperty -Name "VpmPackages" -Value @{ "com.vrchat.base" = "latest" } }
                $exitVpmMenu = $false
                while (-not $exitVpmMenu) {
                    $packagesList = @($config.VpmPackages.PSObject.Properties)
                    $options = @( "A) Add package", "M) Modify package version", "R) Remove package", "S) Save and return" )
                    $headerLines = ""
                    $idx = 0
                    foreach ($pkg in $packagesList) { $idx++; $headerLines += ("  {0}) {1} - {2}`n" -f $idx, $pkg.Name, $pkg.Value) }
                    $selected = Show-Menu -Title '--- VPM Packages configuration ---' -Header $headerLines -Options $options
                    if ($selected -eq -1) { Write-Host "`nOperation canceled." -ForegroundColor Yellow; Start-Sleep -Seconds 1; continue }
                    $vpmChoice = @("A","M","R","S")[$selected]
                    switch ($vpmChoice) {
                        "A" {
                            Write-Host "`nInsert package name to add:" -ForegroundColor Yellow
                            $newPackage = Read-Host "Package name"
                            if ([string]::IsNullOrWhiteSpace($newPackage)) { Write-Host "Package name empty, canceled." -ForegroundColor Yellow; continue }
                            if ($config.VpmPackages.PSObject.Properties.Name -contains $newPackage) { Write-Host "Package already present!" -ForegroundColor Yellow; continue }
                            Write-Host "Insert the version or 'latest':" -ForegroundColor Yellow
                            $newVersion = Read-Host "Version"
                            if ([string]::IsNullOrWhiteSpace($newVersion)) { $newVersion = "latest"; Write-Host "No version specified, using 'latest'" -ForegroundColor Gray }
                            $validation = Test-VpmPackageVersion -PackageName $newPackage -Version $newVersion -ScriptDir $scriptDir
                            if ($validation.Valid) { $config.VpmPackages | Add-Member -MemberType NoteProperty -Name $newPackage -Value $newVersion -Force; Write-Host "Package added: ${newPackage} - ${newVersion}" -ForegroundColor Green; Write-Host "($($validation.Message))" -ForegroundColor Gray } else { Write-Host "Error: $($validation.Message)" -ForegroundColor Red; Write-Host "Package not added." -ForegroundColor Yellow }
                        }
                        "M" {
                            $packagesList = @($config.VpmPackages.PSObject.Properties)
                            if ($packagesList.Count -eq 0) { Write-Host "`nNo package to modify!" -ForegroundColor Yellow; continue }
                            $pkgOptions = $packagesList | ForEach-Object { "{0} - {1}" -f $_.Name, $_.Value }
                            $selectedPkg = Show-Menu -Title 'Select a package to modify:' -Options $pkgOptions -AllowCancel $true
                            if ($selectedPkg -eq -1) { Write-Host "`nOperation canceled." -ForegroundColor Yellow; Start-Sleep -Seconds 1; continue }
                            $pkgToModify = $packagesList[$selectedPkg]
                            Write-Host "`nSelected package: ${($pkgToModify.Name)} (current version: ${($pkgToModify.Value)})" -ForegroundColor Cyan
                            Write-Host "Enter new version (Press ENTER to cancel)" -ForegroundColor Gray
                            $newVersion = Read-Host "New version"
                            if ([string]::IsNullOrWhiteSpace($newVersion)) { Write-Host "Operation canceled." -ForegroundColor Yellow; continue }
                            $validation = Test-VpmPackageVersion -PackageName $pkgToModify.Name -Version $newVersion -ScriptDir $scriptDir
                            if ($validation.Valid) { $config.VpmPackages.($pkgToModify.Name) = $newVersion; Write-Host "Version updated: ${($pkgToModify.Name)} - ${newVersion}" -ForegroundColor Green; Write-Host "($($validation.Message))" -ForegroundColor Gray } else { Write-Host "Error: $($validation.Message)" -ForegroundColor Red; Write-Host "Modification canceled." -ForegroundColor Yellow }
                        }
                        "R" {
                            $packagesList = @($config.VpmPackages.PSObject.Properties)
                            if ($packagesList.Count -eq 0) { Write-Host "`nNo package to remove!" -ForegroundColor Yellow; continue }
                            $pkgOptions = $packagesList | ForEach-Object { "{0} - {1}" -f $_.Name, $_.Value }
                            $selectedPkgRemove = Show-Menu -Title 'Select a package to remove:' -Options $pkgOptions -AllowCancel $true
                            if ($selectedPkgRemove -eq -1) { Write-Host "`nOperation canceled." -ForegroundColor Yellow; Start-Sleep -Seconds 1; continue }
                            $removed = $packagesList[$selectedPkgRemove]
                            $config.VpmPackages.PSObject.Properties.Remove($removed.Name)
                            Write-Host "Package removed: ${($removed.Name)}" -ForegroundColor Green
                        }
                        "S" {
                            $configData = @{ UnityProjectsRoot = $config.UnityProjectsRoot; UnityEditorPath = $config.UnityEditorPath; VpmPackages = $config.VpmPackages }
                            Save-Config -Config $configData -ConfigPath $configPath
                            Write-Host "`nConfiguration saved successfully!" -ForegroundColor Green
                            Start-Sleep -Seconds 1
                            $exitVpmMenu = $true
                        }
                        default { Write-Host "Invalid choice" -ForegroundColor Red }
                    }
                }
                Read-Host "`nPress ENTER to return to main menu"
                Clear-Host
            }

            "4" {
                Clear-Host
                Write-Host "`n--- Reset configuration ---" -ForegroundColor Cyan
                Write-Host "Are you sure you want to reset the configuration?" -ForegroundColor Yellow
                Write-Host "(Press ENTER to cancel)" -ForegroundColor Gray
                $confirm = Read-Host "Confirm [y/n]"
                if ([string]::IsNullOrWhiteSpace($confirm) -or $confirm.ToLower() -ne "y") { Write-Host "Reset canceled." -ForegroundColor Gray; Start-Sleep -Seconds 1 } else { Start-Installer -projectPath "-reset"; Read-Host "Press ENTER to continue" }
            }

            "5" { Write-Host "`nGoodbye! :)" -ForegroundColor Cyan; exit 0 }
            default { Write-Host "`nInvalid choice, try again." -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
    }
}

if ($MyInvocation.InvocationName -ne '') { Start-Wizard }

# Default: run the wizard if the script is invoked directly
if ($MyInvocation.InvocationName -ne '') { 
    # the script runs its interactive menu on invocation
}

Export-ModuleMember -Function Start-Wizard
