# Test rapido della validazione VPM

# Carica la funzione
. "c:\Users\domix\.scriptsdum\UNITY PROJECTS SCRIPT\setup-scripts\vrcsetup-wizard.ps1"

Write-Host "`n=== Test Validazione VPM ===" -ForegroundColor Cyan

# Test 1: Versione latest (sempre valida)
Write-Host "`n[Test 1] adjerry91.vrcft.templates @ latest" -ForegroundColor Yellow
$result = Test-VpmPackageVersion -PackageName "adjerry91.vrcft.templates" -Version "latest"
Write-Host "Valido: $($result.Valid) - $($result.Message)" -ForegroundColor $(if ($result.Valid) { "Green" } else { "Red" })

# Test 2: Versione esistente (6.8.0)
Write-Host "`n[Test 2] adjerry91.vrcft.templates @ 6.8.0" -ForegroundColor Yellow
$result = Test-VpmPackageVersion -PackageName "adjerry91.vrcft.templates" -Version "6.8.0"
Write-Host "Valido: $($result.Valid) - $($result.Message)" -ForegroundColor $(if ($result.Valid) { "Green" } else { "Red" })

# Test 3: Versione inesistente
Write-Host "`n[Test 3] adjerry91.vrcft.templates @ 99.99.99" -ForegroundColor Yellow
$result = Test-VpmPackageVersion -PackageName "adjerry91.vrcft.templates" -Version "99.99.99"
Write-Host "Valido: $($result.Valid) - $($result.Message)" -ForegroundColor $(if ($result.Valid) { "Green" } else { "Red" })

# Test 4: Package VRChat ufficiale
Write-Host "`n[Test 4] com.vrchat.avatars @ latest" -ForegroundColor Yellow
$result = Test-VpmPackageVersion -PackageName "com.vrchat.avatars" -Version "latest"
Write-Host "Valido: $($result.Valid) - $($result.Message)" -ForegroundColor $(if ($result.Valid) { "Green" } else { "Red" })

Write-Host "`n=== Test Completati ===" -ForegroundColor Cyan
