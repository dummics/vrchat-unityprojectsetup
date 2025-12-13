# lib/config.ps1 - simple config helpers
function Initialize-ConfigIfMissing {
    param(
        [string]$ConfigPath,
        [string]$DefaultsPath
    )

    if (-not $ConfigPath) { throw 'ConfigPath is required' }
    if (Test-Path $ConfigPath) { return $false }
    $hasTemplate = ($DefaultsPath -and (Test-Path $DefaultsPath))

    $configDir = Split-Path -Parent $ConfigPath
    if ($configDir -and (-not (Test-Path $configDir))) {
        New-Item -Path $configDir -ItemType Directory -Force | Out-Null
    }

    if ($hasTemplate) {
        Copy-Item -Path $DefaultsPath -Destination $ConfigPath -Force
        return $true
    }

    # Worst-case fallback: generate a minimal skeleton.
    $skeleton = [pscustomobject]@{
        VpmPackages = [pscustomobject]@{
            'com.vrchat.base' = 'latest'
            'com.vrchat.avatars' = 'latest'
            'com.vrchat.core.vpm-resolver' = 'latest'
        }
        UnityEditorPath = ''
        UnityProjectsRoot = ''
        Naming = [pscustomobject]@{
            DefaultPrefix = ''
            DefaultSuffix = ''
            RegexRemovePatterns = @()
            RememberUnityPackageNames = $true
        }
        SavedProjectNames = [pscustomobject]@{}
        LastProjectName = ''
        LastUnityPackagePath = ''
        UnityPackagesFolder = $null
    }

    $skeleton | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath -Encoding UTF8
    return $true
}

function Load-Config {
    param([string]$ConfigPath)
    if (-not $ConfigPath) { throw 'ConfigPath is required' }
    if (-not (Test-Path $ConfigPath)) { return $null }
    return Get-Content $ConfigPath -Raw | ConvertFrom-Json
}

function Save-Config {
    param($Config, [string]$ConfigPath)
    if (-not $ConfigPath) { throw 'ConfigPath required' }
    $Config | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath -Encoding UTF8
}

