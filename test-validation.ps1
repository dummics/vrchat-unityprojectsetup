# Quick VPM validation test

# Carica la funzione
. "$PSScriptRoot\setup-scripts\commands\wizard.ps1"

Write-Host "`n=== VPM Validation Tests ===" -ForegroundColor Cyan

# Test 1: latest version (always valid)
Write-Host "`n[Test 1] adjerry91.vrcft.templates @ latest" -ForegroundColor Yellow
$result = Test-VpmPackageVersion -PackageName "adjerry91.vrcft.templates" -Version "latest" -ScriptDir $PSScriptRoot
Write-Host "Valid: $($result.Valid) - $($result.Message)" -ForegroundColor $(if ($result.Valid) { "Green" } else { "Red" })

# Test 2: existing version (6.8.0)
Write-Host "`n[Test 2] adjerry91.vrcft.templates @ 6.8.0" -ForegroundColor Yellow
$result = Test-VpmPackageVersion -PackageName "adjerry91.vrcft.templates" -Version "6.8.0" -ScriptDir $PSScriptRoot
Write-Host "Valid: $($result.Valid) - $($result.Message)" -ForegroundColor $(if ($result.Valid) { "Green" } else { "Red" })

# Test 3: non-existing version
Write-Host "`n[Test 3] adjerry91.vrcft.templates @ 99.99.99" -ForegroundColor Yellow
$result = Test-VpmPackageVersion -PackageName "adjerry91.vrcft.templates" -Version "99.99.99" -ScriptDir $PSScriptRoot
Write-Host "Valid: $($result.Valid) - $($result.Message)" -ForegroundColor $(if ($result.Valid) { "Green" } else { "Red" })

# Test 4: official VRChat package
Write-Host "`n[Test 4] com.vrchat.avatars @ latest" -ForegroundColor Yellow
$result = Test-VpmPackageVersion -PackageName "com.vrchat.avatars" -Version "latest" -ScriptDir $PSScriptRoot
Write-Host "Valid: $($result.Valid) - $($result.Message)" -ForegroundColor $(if ($result.Valid) { "Green" } else { "Red" })

Write-Host "`n=== Tests Completed ===" -ForegroundColor Cyan
