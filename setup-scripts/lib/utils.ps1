# Utilities for vrc setup scripts
function Install-NUnitPackage {
    param(
        [string]$ProjectPath,
        [switch]$Test
    )

    $manifestPath = Join-Path $ProjectPath "Packages\manifest.json"

    if (-not (Test-Path $manifestPath)) {
        Write-Host "Warning: manifest.json not found, skipping NUnit" -ForegroundColor Yellow
        return
    }

    try {
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json

        # Check se NUnit è già presente
        if ($manifest.dependencies.PSObject.Properties.Name -contains "com.unity.test-framework") {
            Write-Host "NUnit Test Framework already present" -ForegroundColor Gray
            return
        }

        Write-Host "Adding NUnit Test Framework (required by VRChat SDK)..." -ForegroundColor Cyan
        if ($Test) {
            Write-Host "[TEST] Would add com.unity.test-framework @ 1.1.33" -ForegroundColor DarkGray
            Add-Content -Path $global:VRCSETUP_LOGFILE -Value "[TEST] Would add com.unity.test-framework @ 1.1.33 to ${ProjectPath}"
            return
        }
        # Aggiungi NUnit
        $manifest.dependencies | Add-Member -MemberType NoteProperty -Name "com.unity.test-framework" -Value "1.1.33" -Force

        # Salva manifest
        $manifest | ConvertTo-Json -Depth 10 | Set-Content $manifestPath -Encoding UTF8

        Write-Host "NUnit Test Framework added!" -ForegroundColor Green
    } catch {
        Write-Host "Warning: unable to automatically add NUnit: ${_}" -ForegroundColor Yellow
    }
}

