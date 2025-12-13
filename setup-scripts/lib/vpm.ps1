# VPM helpers (backend utilities)
# NOTE: This script is dot-sourced by the wizard.

# Cache: package id -> versions array
$script:VpmVersionsCache = @{}

function Get-VrcSetupLastToolOutput {
    return [string]$global:VRCSETUP_LAST_TOOL_OUTPUT
}

function Invoke-VpmCapture {
    param(
        [string[]]$Arguments
    )

    $output = ""
    try {
        $output = (& vpm @Arguments 2>&1 | Out-String)
    } catch {
        $output = (${_} | Out-String)
    }

    $global:VRCSETUP_LAST_TOOL_OUTPUT = $output
    return @{ ExitCode = $LASTEXITCODE; Output = $output }
}

function Test-VpmCheckOutputIsSuccess {
    param(
        $Result
    )

    if ($null -eq $Result) { return $false }
    if ($Result.ExitCode -ne 0) { return $false }

    $out = [string]$Result.Output
    if ([string]::IsNullOrWhiteSpace($out)) { return $false }

    # VPM can return ExitCode 0 even when it prints a warning like:
    # "[WRN] No directory found at <id>"
    if ($out -match "\[.*ERR.*\]" -or $out -match "\[.*WRN.*\]" -or $out -match "No directory found") {
        return $false
    }

    # For check/show, a successful lookup usually prints INF fields.
    if ($out -match "\[.*INF.*\]" -and $out -match "\bname:\s*") {
        return $true
    }

    return $false
}

function Initialize-VpmTestProject {
    param(
        [string]$ScriptDir
    )

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

function Get-VpmReposPath {
    return (Join-Path $env:LOCALAPPDATA "VRChatCreatorCompanion\Repos")
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
    param(
        [string]$PackageName
    )

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
    $available = Sort-SemVerDescending -Versions $available

    $script:VpmVersionsCache[$PackageName] = @($available)
    return $script:VpmVersionsCache[$PackageName]
}

function Test-VpmPackageExists {
    param(
        [string]$PackageName,
        [string]$ScriptDir
    )

    if ([string]::IsNullOrWhiteSpace($PackageName)) { return $false }

    # Prefer vrc-get if available (it can list versions reliably).
    try {
        $cmd = Get-Command Get-VrcGetAvailableVersions -ErrorAction SilentlyContinue
        if ($cmd) {
            $vrcGetVersions = Get-VrcGetAvailableVersions -PackageName $PackageName -ScriptDir $ScriptDir
            if ($vrcGetVersions.Count -gt 0) { return $true }
        }
    } catch { }

    # Source of truth fallback: VPM itself.
    $res = Invoke-VpmCapture -Arguments @('check', 'package', $PackageName)
    if (Test-VpmCheckOutputIsSuccess -Result $res) { return $true }

    # Secondary: VPM show (some installs support show better than check).
    $res2 = Invoke-VpmCapture -Arguments @('show', 'package', $PackageName)
    if (Test-VpmCheckOutputIsSuccess -Result $res2) { return $true }

    # Fallback: local VCC repos cache (useful for version listing).
    $versions = Get-VpmAvailableVersions -PackageName $PackageName
    if ($versions.Count -gt 0) { return $true }

    return $false
}

function Test-VpmPackageVersion {
    param(
        [string]$PackageName,
        [string]$Version,
        [string]$ScriptDir
    )

    if ([string]::IsNullOrWhiteSpace($PackageName)) {
        return @{ Valid = $false; Message = "Package name is empty" }
    }
    if ([string]::IsNullOrWhiteSpace($Version)) {
        return @{ Valid = $false; Message = "Version is empty" }
    }

    # Validate existence even for 'latest'
    if ($Version -eq "latest") {
        try {
            $cmd = Get-Command Get-VrcGetAvailableVersions -ErrorAction SilentlyContinue
            if ($cmd) {
                $vrcGetVersions = Get-VrcGetAvailableVersions -PackageName $PackageName -ScriptDir $ScriptDir
                if ($vrcGetVersions.Count -gt 0) {
                    return @{ Valid = $true; Message = "Validated with vrc-get (latest)" }
                }
            }
        } catch { }

        $res = Invoke-VpmCapture -Arguments @('check', 'package', $PackageName)
        if (Test-VpmCheckOutputIsSuccess -Result $res) {
            return @{ Valid = $true; Message = "Validated with VPM (latest)" }
        }

        return @{ Valid = $false; Message = "Package not found or not resolvable (latest)" }
    }

    $testProject = Initialize-VpmTestProject -ScriptDir $ScriptDir
    try {
        $packageSpec = "${PackageName}@${Version}"
        $output = vpm add package $packageSpec -p $testProject 2>&1 | Out-String
        $global:VRCSETUP_LAST_TOOL_OUTPUT = $output

        if ($LASTEXITCODE -ne 0 -or $output -match "ERR.*Could not get match" -or $output -match "ERR.*not found") {
            $reposPath = Get-VpmReposPath
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

            return @{ Valid = $false; Message = "Version ${Version} not available" }
        }

        vpm remove package $PackageName -p $testProject 2>&1 | Out-Null
        return @{ Valid = $true; Message = "Version verified with VPM" }
    } catch {
        $global:VRCSETUP_LAST_TOOL_OUTPUT = (${_} | Out-String)
        return @{ Valid = $false; Message = "VPM validation error" }
    }
}
