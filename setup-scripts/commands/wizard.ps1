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

$script:VpmVersionsCache = @{}
$script:LastVpmOutput = $null

# Main installer function is provided by commands\installer.ps1 (Start-Installer)

# --- FUNCTIONS ---
function Initialize-VpmTestProject {
    param([string]$ScriptDir)
    $testProjectPath = Join-Path $ScriptDir ".vpm-validation-cache"
    if (Test-Path ${testProjectPath}) {
        return $testProjectPath
    }
    Write-Host "Initializing VPM validation cache (first run)..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $testProjectPath -Force | Out-Null
    $packagesPath = Join-Path $testProjectPath "Packages"
    New-Item -ItemType Directory -Path $packagesPath -Force | Out-Null
    $manifest = @{ dependencies = @{ } }
    $manifest | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $packagesPath "manifest.json") -Encoding UTF8
    $vpmManifest = @{ dependencies = @{ }; locked = @{ } }
    $vpmManifest | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $packagesPath "vpm-manifest.json") -Encoding UTF8
    Write-Host "Cache created at: ${testProjectPath}" -ForegroundColor Green
    return $testProjectPath
}

function Invoke-VpmCapture {
    param(
        [string[]]$Args
    )

    $output = ""
    try {
        $output = (& vpm @Args 2>&1 | Out-String)
    } catch {
        $output = (${_} | Out-String)
    }

    return @{ ExitCode = $LASTEXITCODE; Output = $output }
}

function Get-LastTextLines {
    param(
        [string]$Text,
        [int]$MaxLines = 20
    )
    if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
    $lines = $Text -split "`r?`n"
    return ($lines | Select-Object -Last $MaxLines) -join "`n"
}

function Show-WizardError {
    param(
        [string]$Title,
        [string]$Message,
        [string]$Details
    )
    Clear-Host
    Write-Host $Title -ForegroundColor Red
    Write-Host "" 
    if ($Message) { Write-Host $Message -ForegroundColor Yellow }
    if ($Details) {
        Write-Host "" 
        Write-Host "Details (last lines):" -ForegroundColor DarkGray
        Write-Host $Details -ForegroundColor Gray
    }
    Write-Host "" 
    Read-Host "Press ENTER to continue" | Out-Null
}

function Test-VpmPackageVersion {
    param([string]$PackageName, [string]$Version, [string]$ScriptDir)

    if ([string]::IsNullOrWhiteSpace($PackageName)) {
        return @{ Valid = $false; Message = "Package name is empty" }
    }
    if ([string]::IsNullOrWhiteSpace($Version)) {
        return @{ Valid = $false; Message = "Version is empty" }
    }

    # Validate existence even for 'latest' (use correct vpm command)
    if ($Version -eq "latest") {
        $res = Invoke-VpmCapture -Args @('check', 'package', $PackageName)
        $script:LastVpmOutput = $res.Output
        if ($res.ExitCode -eq 0) {
            return @{ Valid = $true; Message = "Validated with VPM (latest)" }
        }
        $tail = Get-LastTextLines -Text $res.Output -MaxLines 25
        return @{ Valid = $false; Message = "Package not found or not resolvable (latest)"; Details = $tail }
    }

    Write-Host "Validating ${PackageName}@${Version}..." -ForegroundColor Gray
    $testProject = Initialize-VpmTestProject -ScriptDir $ScriptDir
    try {
        $packageSpec = "${PackageName}@${Version}"
        $output = vpm add package $packageSpec -p $testProject 2>&1 | Out-String
        $script:LastVpmOutput = $output
        if ($LASTEXITCODE -ne 0 -or $output -match "ERR.*Could not get match" -or $output -match "ERR.*not found") {
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
                return @{ Valid = $false; Message = "Version ${Version} not found. Recent versions: ${versionList}" }
            }
            $tail = Get-LastTextLines -Text $output -MaxLines 25
            return @{ Valid = $false; Message = "Version ${Version} not available"; Details = $tail }
        }
        Write-Host "Version valid!" -ForegroundColor Green
        vpm remove package $PackageName -p $testProject 2>&1 | Out-Null
        return @{ Valid = $true; Message = "Versione verificata con VPM" }
    } catch {
        $script:LastVpmOutput = (${_} | Out-String)
        return @{ Valid = $false; Message = "VPM validation error"; Details = (Get-LastTextLines -Text $script:LastVpmOutput -MaxLines 25) }
    }
}

function Normalize-UserPath {
    param([string]$Path)
    if ($null -eq $Path) { return $null }
    $p = $Path.Trim()
    $p = $p.Trim('"')
    $p = $p.Trim("'")
    return $p
}

function Get-VpmReposPath {
    return (Join-Path $env:LOCALAPPDATA "VRChatCreatorCompanion\Repos")
}

function Ensure-ConfigDefaults {
    param($Config)
    if (-not $Config) { return $null }

    if (-not $Config.Naming) {
        $Config | Add-Member -MemberType NoteProperty -Name "Naming" -Value ([pscustomobject]@{}) -Force
    }

    if ($null -eq $Config.Naming.DefaultPrefix) { $Config.Naming | Add-Member -MemberType NoteProperty -Name "DefaultPrefix" -Value "" -Force }
    if ($null -eq $Config.Naming.DefaultSuffix) { $Config.Naming | Add-Member -MemberType NoteProperty -Name "DefaultSuffix" -Value "" -Force }
    if ($null -eq $Config.Naming.RegexRemovePatterns) { $Config.Naming | Add-Member -MemberType NoteProperty -Name "RegexRemovePatterns" -Value @() -Force }
    if ($null -eq $Config.Naming.RememberUnityPackageNames) { $Config.Naming | Add-Member -MemberType NoteProperty -Name "RememberUnityPackageNames" -Value $true -Force }

    if (-not $Config.SavedProjectNames) {
        $Config | Add-Member -MemberType NoteProperty -Name "SavedProjectNames" -Value ([pscustomobject]@{}) -Force
    }

    return $Config
}

function Apply-ProjectNamingRules {
    param(
        [string]$BaseName,
        $Config
    )
    if ([string]::IsNullOrWhiteSpace($BaseName)) { return $BaseName }
    if (-not $Config) { return $BaseName }

    $name = $BaseName
    $cfg = Ensure-ConfigDefaults -Config $Config
    $patterns = @($cfg.Naming.RegexRemovePatterns)
    foreach ($pat in $patterns) {
        if ([string]::IsNullOrWhiteSpace($pat)) { continue }
        try {
            $name = ($name -replace $pat, "")
        } catch {
            # ignore invalid regex
        }
    }

    $name = $name.Trim()
    $name = ($cfg.Naming.DefaultPrefix + $name + $cfg.Naming.DefaultSuffix).Trim()
    return $name
}

function Advanced-NamingSettings {
    param(
        [string]$ConfigPath
    )

    if (-not (Test-Path $ConfigPath)) {
        Write-Host "Config not found. Run setup first." -ForegroundColor Red
        Read-Host "Press ENTER to continue"
        return
    }

    $config = Load-Config -ConfigPath $ConfigPath
    $config = Ensure-ConfigDefaults -Config $config

    while ($true) {
        $patternsCount = @($config.Naming.RegexRemovePatterns).Count
        $remember = if ($config.Naming.RememberUnityPackageNames) { "ON" } else { "OFF" }
        $header = "Prefix: '$($config.Naming.DefaultPrefix)'  Suffix: '$($config.Naming.DefaultSuffix)'`nRegex remove patterns: ${patternsCount}`nRemember per-unitypackage names: ${remember}"

        $sel = Show-Menu -Title "Advanced settings" -Header $header -Options @(
            "Set default prefix",
            "Set default suffix",
            "Manage regex remove patterns",
            "Toggle remember unitypackage names",
            "Back"
        )

        if ($sel -eq -1 -or $sel -eq 4) { Save-Config -Config $config -ConfigPath $ConfigPath; return }

        switch ($sel) {
            0 {
                $p = Read-Host "Default prefix (blank to clear)"
                $config.Naming.DefaultPrefix = if ($p) { $p } else { "" }
                Save-Config -Config $config -ConfigPath $ConfigPath
            }
            1 {
                $s = Read-Host "Default suffix (blank to clear)"
                $config.Naming.DefaultSuffix = if ($s) { $s } else { "" }
                Save-Config -Config $config -ConfigPath $ConfigPath
            }
            2 {
                while ($true) {
                    $patterns = @($config.Naming.RegexRemovePatterns)
                    $opts = @()
                    foreach ($pat in $patterns) { $opts += $pat }
                    $opts += @("Add pattern", "Remove pattern", "Back")

                    $pSel = Show-Menu -Title "Regex remove patterns" -Header "These patterns will be removed from the suggested project name." -Options $opts
                    if ($pSel -eq -1 -or $opts[$pSel] -eq "Back") { break }

                    if ($opts[$pSel] -eq "Add pattern") {
                        $newPat = Read-Host "Regex pattern to remove"
                        if ([string]::IsNullOrWhiteSpace($newPat)) { continue }
                        try {
                            [void][regex]::new($newPat)
                        } catch {
                            Write-Host "Invalid regex." -ForegroundColor Red
                            Read-Host "Press ENTER"
                            continue
                        }
                        $config.Naming.RegexRemovePatterns += @($newPat)
                        Save-Config -Config $config -ConfigPath $ConfigPath
                        continue
                    }

                    if ($opts[$pSel] -eq "Remove pattern") {
                        if ($patterns.Count -eq 0) { continue }
                        $idx = Show-Menu -Title "Remove which pattern?" -Options $patterns
                        if ($idx -eq -1) { continue }
                        $toRemove = $patterns[$idx]
                        $config.Naming.RegexRemovePatterns = @($patterns | Where-Object { $_ -ne $toRemove })
                        Save-Config -Config $config -ConfigPath $ConfigPath
                        continue
                    }
                }
            }
            3 {
                $config.Naming.RememberUnityPackageNames = -not $config.Naming.RememberUnityPackageNames
                Save-Config -Config $config -ConfigPath $ConfigPath
            }
        }
    }
}

function Get-AllVpmPackageNames {
    $reposPath = Get-VpmReposPath
    $names = @()
    if (Test-Path $reposPath) {
        Get-ChildItem $reposPath -Filter "*.json" -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $repoData = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
                if ($repoData.packages) {
                    $names += $repoData.packages.PSObject.Properties.Name
                }
            } catch { }
        }
    }
    return ($names | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique | Sort-Object)
}

function Get-VpmAvailableVersions {
    param([string]$PackageName)
    if ([string]::IsNullOrWhiteSpace($PackageName)) { return @() }

    if ($script:VpmVersionsCache.ContainsKey($PackageName)) {
        return $script:VpmVersionsCache[$PackageName]
    }

    $reposPath = Get-VpmReposPath
    $available = @()
    if (Test-Path $reposPath) {
        Get-ChildItem $reposPath -Filter "*.json" -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $repoData = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
                if (${repoData.packages}.${PackageName}) {
                    $versions = $repoData.packages.$PackageName.versions.PSObject.Properties.Name
                    if ($versions) {
                        $available += $versions
                    }
                }
            } catch { }
        }
    }

    $available = $available | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique
    $available = $available | Sort-Object -Descending

    $script:VpmVersionsCache[$PackageName] = @($available)
    return $script:VpmVersionsCache[$PackageName]
}

function Test-VpmPackageExists {
    param([string]$PackageName)

    if ([string]::IsNullOrWhiteSpace($PackageName)) { return $false }

    # Source of truth: VPM itself.
    $res = Invoke-VpmCapture -Args @('check', 'package', $PackageName)
    $script:LastVpmOutput = $res.Output
    if ($res.ExitCode -eq 0) { return $true }

    # Secondary: VPM show (some installs support show better than check).
    $res2 = Invoke-VpmCapture -Args @('show', 'package', $PackageName)
    $script:LastVpmOutput = $res2.Output
    if ($res2.ExitCode -eq 0) { return $true }

    # Fallback: local VCC repos cache (useful for version listing).
    $versions = Get-VpmAvailableVersions -PackageName $PackageName
    if ($versions.Count -gt 0) { return $true }

    return $false
}

function Select-VpmVersion {
    param(
        [string]$PackageName,
        [string]$CurrentVersion
    )

    $available = Get-VpmAvailableVersions -PackageName $PackageName
    $header = "Package: ${PackageName}`nCurrent: ${CurrentVersion}`n"
    if ($available.Count -gt 0) {
        $header += "Versions found locally: ${($available.Count)} (from VCC repos)`n"
    } else {
        $header += "No versions found locally. You can still enter manually.`n"
    }

    $options = @("latest")
    $options += ($available | Select-Object -First 20)
    $options += @("Enter manually", "Back")

    $sel = Show-Menu -Title "Select version" -Header $header -Options $options
    if ($sel -eq -1) { return $null }

    $picked = $options[$sel]
    if ($picked -eq "Back") { return $null }
    if ($picked -eq "Enter manually") {
        $manual = Read-Host "Version (or 'latest')"
        if ([string]::IsNullOrWhiteSpace($manual)) { return $null }
        return $manual.Trim()
    }

    return $picked
}

function Edit-VpmPackages {
    param(
        [string]$ConfigPath,
        [string]$ScriptDir
    )

    if (-not (Test-Path $ConfigPath)) {
        Write-Host "Config not found. Run setup first." -ForegroundColor Red
        Read-Host "Press ENTER to continue"
        return
    }

    $config = Load-Config -ConfigPath $ConfigPath
    if (-not $config) {
        Write-Host "Unable to load config." -ForegroundColor Red
        Read-Host "Press ENTER to continue"
        return
    }

    if ($config.VpmPackages -is [System.Array]) {
        $newPackages = @{}
        foreach ($pkg in $config.VpmPackages) { $newPackages[$pkg] = "latest" }
        $config.VpmPackages = [pscustomobject]$newPackages
    }
    if (-not $config.VpmPackages) {
        $config | Add-Member -MemberType NoteProperty -Name "VpmPackages" -Value ([pscustomobject]@{ "com.vrchat.base" = "latest" }) -Force
    }

    while ($true) {
        $packagesList = @($config.VpmPackages.PSObject.Properties) | Sort-Object Name
        $pkgOptions = @()
        foreach ($pkg in $packagesList) {
            $pkgOptions += ("{0}  [{1}]" -f $pkg.Name, $pkg.Value)
        }
        $pkgOptions += @("Add package", "Back")

        $header = "Select a package, then choose an action."
        $selected = Show-Menu -Title "VPM Packages" -Header $header -Options $pkgOptions
        if ($selected -eq -1) { return }

        $picked = $pkgOptions[$selected]
        if ($picked -eq "Back") { return }

        if ($picked -eq "Add package") {
            $allPackages = Get-AllVpmPackageNames
            $manualOption = "(Enter package name manually)"
            $opts = @($manualOption) + @($allPackages)
            $pickedName = Show-MenuFilter \
                -Title "Add package" \
                -Header "Type to filter. Enter selects. If no match, Enter uses the typed text." \
                -Options $opts \
                -PinnedOptions @($manualOption) \
                -Placeholder "type package name (e.g. gogoloco, poiyomi)"
            if ($null -eq $pickedName) { continue }

            $newPackage = $null
            if ($pickedName -eq $manualOption) {
                $newPackage = Read-Host "Package name"
                $newPackage = $newPackage.Trim()
            } else {
                $newPackage = $pickedName
            }

            # If user pressed Enter with zero matches, Show-MenuFilter returns the typed filter string.
            $newPackage = $newPackage.Trim()

            if ([string]::IsNullOrWhiteSpace($newPackage)) { continue }

            # Make intent clear for the next step
            Write-Host "Selected package: ${newPackage}" -ForegroundColor Cyan

            if ($config.VpmPackages.PSObject.Properties.Name -contains $newPackage) {
                Write-Host "Package already present." -ForegroundColor Yellow
                Start-Sleep -Seconds 1
                continue
            }

            if (-not (Test-VpmPackageExists -PackageName $newPackage)) {
                $tail = Get-LastTextLines -Text $script:LastVpmOutput -MaxLines 25
                Show-WizardError -Title "Package not found" -Message "Package not found / not resolvable: ${newPackage}" -Details $tail
                continue
            }

            $version = Select-VpmVersion -PackageName $newPackage -CurrentVersion "(new)"
            if ($null -eq $version) { continue }

            $validation = Test-VpmPackageVersion -PackageName $newPackage -Version $version -ScriptDir $ScriptDir
            if (-not $validation.Valid) {
                Show-WizardError -Title "Validation failed" -Message $validation.Message -Details $validation.Details
                continue
            }

            $config.VpmPackages | Add-Member -MemberType NoteProperty -Name $newPackage -Value $version -Force
            Save-Config -Config $config -ConfigPath $ConfigPath
            Write-Host "Package added: ${newPackage} @ ${version}" -ForegroundColor Green
            Start-Sleep -Seconds 1
            continue
        }

        # A real package selected
        $pkgProp = $packagesList[$selected]
        $pkgName = $pkgProp.Name
        $pkgVersion = $pkgProp.Value

        $action = Show-Menu -Title "Package: ${pkgName}" -Header "Current: ${pkgVersion}" -Options @("Change version", "Remove package", "Back")
        if ($action -eq -1 -or $action -eq 2) { continue }

        if ($action -eq 0) {
            if (-not (Test-VpmPackageExists -PackageName $pkgName)) {
                $tail = Get-LastTextLines -Text $script:LastVpmOutput -MaxLines 25
                Show-WizardError -Title "Package not found" -Message "Package not found / not resolvable: ${pkgName}" -Details $tail
                continue
            }

            $newVersion = Select-VpmVersion -PackageName $pkgName -CurrentVersion $pkgVersion
            if ($null -eq $newVersion) { continue }

            $validation = Test-VpmPackageVersion -PackageName $pkgName -Version $newVersion -ScriptDir $ScriptDir
            if (-not $validation.Valid) {
                Show-WizardError -Title "Validation failed" -Message $validation.Message -Details $validation.Details
                continue
            }

            $config.VpmPackages.($pkgName) = $newVersion
            Save-Config -Config $config -ConfigPath $ConfigPath
            Write-Host "Updated: ${pkgName} @ ${newVersion}" -ForegroundColor Green
            Start-Sleep -Seconds 1
            continue
        }

        if ($action -eq 1) {
            $confirm = Show-Menu -Title "Remove package" -Header "Remove ${pkgName}?" -Options @("Yes, remove", "Cancel") -AllowCancel $false
            if ($confirm -eq 0) {
                $config.VpmPackages.PSObject.Properties.Remove($pkgName)
                Save-Config -Config $config -ConfigPath $ConfigPath
                Write-Host "Removed: ${pkgName}" -ForegroundColor Green
                Start-Sleep -Seconds 1
            }
            continue
        }
    }
}

function Setup-ProjectFlow {
    param([string]$ConfigPath)

    $setupChoice = Show-Menu -Title "Setup project" -Header "Choose what you're starting from:" -Options @(
        "UnityPackage (.unitypackage) -> create new project",
        "Existing Unity project folder",
        "Back"
    )

    if ($setupChoice -eq -1 -or $setupChoice -eq 2) { return }

    $config = $null
    if (Test-Path $ConfigPath) { $config = Load-Config -ConfigPath $ConfigPath }
    if ($config) { $config = Ensure-ConfigDefaults -Config $config }

    if ($setupChoice -eq 0) {
        Write-Host "Drag here the .unitypackage file (or paste the full path):" -ForegroundColor Yellow
        $packagePath = Normalize-UserPath (Read-Host "UnityPackage path")
        if ([string]::IsNullOrWhiteSpace($packagePath)) { return }
        if (-not (Test-Path $packagePath)) { Write-Host "Path not found: ${packagePath}" -ForegroundColor Red; Read-Host "Press ENTER"; return }
        if ($packagePath -notlike "*.unitypackage") { Write-Host "Must be a .unitypackage file." -ForegroundColor Red; Read-Host "Press ENTER"; return }

        $rawDefault = [System.IO.Path]::GetFileNameWithoutExtension($packagePath)
        $defaultName = Apply-ProjectNamingRules -BaseName $rawDefault -Config $config

        $savedName = $null
        if ($config -and $config.SavedProjectNames -and $config.SavedProjectNames.PSObject.Properties.Name -contains $packagePath) {
            $savedName = $config.SavedProjectNames.($packagePath)
        }

        $hint = if ($savedName) { "saved = ${savedName}" } elseif ($config -and $config.LastProjectName) { "last = $($config.LastProjectName)" } else { $null }
        $prompt = if ($hint) { "Project name (ENTER = ${defaultName}, ${hint})" } else { "Project name (ENTER = ${defaultName})" }

        $projectName = (Read-Host $prompt)
        if ([string]::IsNullOrWhiteSpace($projectName)) { $projectName = if ($savedName) { $savedName } else { $defaultName } } else { $projectName = $projectName.Trim() }

        $confirmHeader = "UnityPackage: ${packagePath}`nProject name: ${projectName}`n\nProceed?"
        $confirm = Show-Menu -Title "Confirm" -Header $confirmHeader -Options @("Proceed", "Cancel") -AllowCancel $false
        if ($confirm -ne 0) { return }

        if ($config) {
            $config | Add-Member -MemberType NoteProperty -Name "LastProjectName" -Value $projectName -Force
            $config | Add-Member -MemberType NoteProperty -Name "LastUnityPackagePath" -Value $packagePath -Force
            if ($config.Naming.RememberUnityPackageNames) {
                $config.SavedProjectNames | Add-Member -MemberType NoteProperty -Name $packagePath -Value $projectName -Force
            }
            Save-Config -Config $config -ConfigPath $ConfigPath
        }

        Start-Installer -projectPath $packagePath -NewProjectName $projectName
        Read-Host "Press ENTER to return"
        return
    }

    if ($setupChoice -eq 1) {
        Write-Host "Drag here the Unity project folder (or paste the path):" -ForegroundColor Yellow
        $projectPath = Normalize-UserPath (Read-Host "Project path")
        if ([string]::IsNullOrWhiteSpace($projectPath)) { return }
        if (-not (Test-Path $projectPath)) { Write-Host "Path not found: ${projectPath}" -ForegroundColor Red; Read-Host "Press ENTER"; return }

        $assetsPath = Join-Path $projectPath "Assets"
        if (-not (Test-Path $assetsPath)) { Write-Host "Not a Unity project (missing Assets)." -ForegroundColor Red; Read-Host "Press ENTER"; return }

        $confirmHeader = "Project folder: ${projectPath}`n\nProceed?"
        $confirm = Show-Menu -Title "Confirm" -Header $confirmHeader -Options @("Proceed", "Cancel") -AllowCancel $false
        if ($confirm -ne 0) { return }

        Start-Installer -projectPath $projectPath
        Read-Host "Press ENTER to return"
        return
    }
}

# --- Main launcher for interactive wizard ---
function Start-Wizard {
    while ($true) {
        $header = "Use arrows + Enter. ESC cancels." 
        $choice = Show-Menu -Title "VRChat Project Setup Wizard" -Header $header -Options @(
            "Setup project (UnityPackage or existing)",
            "Configure VPM packages",
            "Advanced settings",
            "Reset configuration",
            "Exit"
        )

        if ($choice -eq -1) { continue }

        switch ($choice) {
            0 {
                Setup-ProjectFlow -ConfigPath $configPath
            }
            1 {
                Edit-VpmPackages -ConfigPath $configPath -ScriptDir $scriptDir
            }
            2 {
                Advanced-NamingSettings -ConfigPath $configPath
            }
            3 {
                $confirm = Show-Menu -Title "Reset configuration" -Header "Reset config file?" -Options @("Yes, reset", "Cancel") -AllowCancel $false
                if ($confirm -eq 0) {
                    Start-Installer -projectPath "-reset"
                    Read-Host "Press ENTER to continue"
                }
            }
            4 {
                Write-Host "Goodbye!" -ForegroundColor Cyan
                return
            }
        }
    }
}

