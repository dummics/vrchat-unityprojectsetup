# vrc-setup.ps1
param([string]$projectPath, [switch]$Test)

# === CARICAMENTO CONFIG ===
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$logDir = Join-Path $scriptDir 'logs'
if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
$global:VRCSETUP_LOGFILE = Join-Path $logDir "vrcsetup-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$configPath = Join-Path $scriptDir "vrcsetup.config"

# Check per reset config
if ($projectPath -eq "-reset") {
    if (Test-Path $configPath) {
        Remove-Item $configPath -Force
        Write-Host "Configurazione resettata!" -ForegroundColor Green
        Write-Host "Alla prossima esecuzione verra' richiesta la configurazione." -ForegroundColor Gray
    } else {
        Write-Host "Nessuna configurazione da resettare." -ForegroundColor Yellow
    }
    exit 0
}

# Carica o richiedi configurazione
$configValid = $false
while (-not $configValid) {
    if (Test-Path $configPath) {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
        $UNITY_PROJECTS_ROOT = $config.UnityProjectsRoot
        $UNITY_EDITOR_PATH = $config.UnityEditorPath
        $VPM_PACKAGES = $config.VpmPackages
        
        # Se VpmPackages non esiste nel config, usa default
        if (-not $VPM_PACKAGES) {
            $VPM_PACKAGES = @{
                "com.vrchat.base" = "latest"
                "com.vrchat.avatars" = "latest"
                "com.poiyomi.toon" = "latest"
                "adjerry91.vrcft.templates" = "latest"
                "com.vrcfury.vrcfury" = "latest"
                "gogoloco" = "latest"
                "com.vrchat.core.vpm-resolver" = "latest"
            }
        }
        
        # Converti vecchio formato array a nuovo formato hashtable se necessario
        if ($VPM_PACKAGES -is [System.Array]) {
            Write-Host "Conversione formato packages a nuovo formato con versioni..." -ForegroundColor Yellow
            $newPackages = @{}
            foreach ($pkg in $VPM_PACKAGES) {
                $newPackages[$pkg] = "latest"
            }
            $VPM_PACKAGES = $newPackages
            
            # Salva la configurazione aggiornata
            $configData = @{
                UnityProjectsRoot = $UNITY_PROJECTS_ROOT
                UnityEditorPath = $UNITY_EDITOR_PATH
                VpmPackages = $VPM_PACKAGES
            }
            $configData | ConvertTo-Json | Set-Content $configPath -Encoding UTF8
            Write-Host "Configurazione aggiornata!" -ForegroundColor Green
        }
        
        # Valida configurazione
        if (-not (Test-Path $UNITY_PROJECTS_ROOT)) {
            Write-Host "Errore: Unity Projects Root non trovato: $UNITY_PROJECTS_ROOT" -ForegroundColor Red
            Write-Host "Riconfigurazione necessaria..." -ForegroundColor Yellow
            Remove-Item $configPath -Force
            continue
        }
        
        if (-not (Test-Path $UNITY_EDITOR_PATH)) {
            Write-Host "Errore: Unity Editor non trovato: $UNITY_EDITOR_PATH" -ForegroundColor Red
            Write-Host "Riconfigurazione necessaria..." -ForegroundColor Yellow
            Remove-Item $configPath -Force
            continue
        }
        
        $configValid = $true
    } else {
        Write-Host "=== Prima configurazione di vrcsetupflowye ===" -ForegroundColor Cyan
        
        # Loop per Unity Projects Root
        $validProjectsRoot = $false
        while (-not $validProjectsRoot) {
            Write-Host "`nInserisci il path della cartella dove Unity crea i progetti:" -ForegroundColor Yellow
            $UNITY_PROJECTS_ROOT = Read-Host "Unity Projects Root"
            
            if ([string]::IsNullOrWhiteSpace($UNITY_PROJECTS_ROOT)) {
                Write-Host "Path vuoto, riprova!" -ForegroundColor Red
                continue
            }
            
            # Valida Unity Projects Root
            if (-not (Test-Path $UNITY_PROJECTS_ROOT)) {
                Write-Host "Errore: path non trovato: $UNITY_PROJECTS_ROOT" -ForegroundColor Red
                Write-Host "Riprova..." -ForegroundColor Yellow
                continue
            }
            
            $validProjectsRoot = $true
        }
        
        # Loop per Unity Editor Path
        $validEditorPath = $false
        while (-not $validEditorPath) {
            Write-Host "`nInserisci il path della cartella Unity Editor:" -ForegroundColor Yellow
            Write-Host "(es. C:\Program Files\Unity\Hub\Editor\2022.3.22f1\Editor)" -ForegroundColor Gray
            $UNITY_EDITOR_FOLDER = Read-Host "Unity Editor Folder"
            
            if ([string]::IsNullOrWhiteSpace($UNITY_EDITOR_FOLDER)) {
                Write-Host "Path vuoto, riprova!" -ForegroundColor Red
                continue
            }
            
            # Valida Unity Editor Folder
            if (-not (Test-Path $UNITY_EDITOR_FOLDER)) {
                Write-Host "Errore: cartella non trovata: $UNITY_EDITOR_FOLDER" -ForegroundColor Red
                Write-Host "Riprova..." -ForegroundColor Yellow
                continue
            }
            
            # Cerca Unity.exe nella cartella
            $UNITY_EDITOR_PATH = Join-Path $UNITY_EDITOR_FOLDER "Unity.exe"
            if (-not (Test-Path $UNITY_EDITOR_PATH)) {
                Write-Host "Errore: Unity.exe non trovato in: $UNITY_EDITOR_FOLDER" -ForegroundColor Red
                Write-Host "Riprova..." -ForegroundColor Yellow
                continue
            }
            
            Write-Host "Trovato Unity.exe: $UNITY_EDITOR_PATH" -ForegroundColor Green
            $validEditorPath = $true
        }
        
        # Salva configurazione solo se valida
        $configData = @{
            UnityProjectsRoot = $UNITY_PROJECTS_ROOT
            UnityEditorPath = $UNITY_EDITOR_PATH
            VpmPackages = @{
                "com.vrchat.base" = "latest"
                "com.vrchat.avatars" = "latest"
                "com.poiyomi.toon" = "latest"
                "adjerry91.vrcft.templates" = "latest"
                "com.vrcfury.vrcfury" = "latest"
                "gogoloco" = "latest"
                "com.vrchat.core.vpm-resolver" = "latest"
            }
        }
        $configData | ConvertTo-Json | Set-Content $configPath -Encoding UTF8
        
        Write-Host "`nConfigurazione salvata in: $configPath" -ForegroundColor Green
        Write-Host "Puoi modificare il file per cambiare i path in futuro.`n" -ForegroundColor Gray
        $configValid = $true
    }
}

# === FUNZIONE: Installa NUnit Test Framework ===
function Install-NUnitPackage {
    param([string]$ProjectPath)
    
    $manifestPath = Join-Path $ProjectPath "Packages\manifest.json"
    
    if (-not (Test-Path $manifestPath)) {
        Write-Host "Warning: manifest.json non trovato, skip NUnit" -ForegroundColor Yellow
        return
    }
    
    try {
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        
        # Check se NUnit è già presente
        if ($manifest.dependencies.PSObject.Properties.Name -contains "com.unity.test-framework") {
            Write-Host "NUnit Test Framework già presente" -ForegroundColor Gray
            return
        }
        
        Write-Host "Aggiunta NUnit Test Framework (richiesto da VRChat SDK)..." -ForegroundColor Cyan
        if ($Test) {
            Write-Host "[TEST] Would add com.unity.test-framework @ 1.1.33" -ForegroundColor DarkGray
            Add-Content -Path $global:VRCSETUP_LOGFILE -Value "[TEST] Would add com.unity.test-framework @ 1.1.33 to $ProjectPath"
            return
        }
        # Aggiungi NUnit
        $manifest.dependencies | Add-Member -MemberType NoteProperty -Name "com.unity.test-framework" -Value "1.1.33" -Force
        
        # Salva manifest
        $manifest | ConvertTo-Json -Depth 10 | Set-Content $manifestPath -Encoding UTF8
        
        Write-Host "NUnit Test Framework aggiunto!" -ForegroundColor Green
    } catch {
        Write-Host "Warning: impossibile aggiungere NUnit automaticamente: $_" -ForegroundColor Yellow
    }
}

# Check 1: Path fornito
if (-not $projectPath) {
    Write-Host "Errore: devi specificare il path del progetto o un .unitypackage" -ForegroundColor Red
    Write-Host "Uso 1: vrc-setup `"C:\Path\To\Project`"" -ForegroundColor Yellow
    Write-Host "Uso 2: vrc-setup `"C:\Path\To\MyPackage.unitypackage`"" -ForegroundColor Yellow
    Write-Host "Optional: append -Test to perform a dry-run: `vrc-setup path -Test`" -ForegroundColor Gray
    exit 1
}

# Check 2: Path esiste
if (-not (Test-Path $projectPath)) {
    Write-Host "Errore: path non trovato: $projectPath" -ForegroundColor Red
    exit 1
}

# === MODALITÀ 1: UnityPackage → Crea nuovo progetto ===
if ($projectPath -like "*.unitypackage") {
    Write-Host "Rilevato UnityPackage: creazione nuovo progetto..." -ForegroundColor Cyan
    
    # Ottieni nome del file senza estensione
    $packageName = [System.IO.Path]::GetFileNameWithoutExtension($projectPath)
    $newProjectPath = Join-Path $UNITY_PROJECTS_ROOT $packageName
    
    # Check se progetto esiste già
    if (Test-Path $newProjectPath) {
        Write-Host "Attenzione: progetto già esistente in: $newProjectPath" -ForegroundColor Yellow
        Write-Host "`nCosa vuoi fare?" -ForegroundColor Yellow
        Write-Host "  1) Salta creazione progetto e continua con import package + VPM setup" -ForegroundColor White
        Write-Host "  2) Salta creazione progetto, solo VPM setup (no import package)" -ForegroundColor White
        Write-Host "  3) Annulla operazione" -ForegroundColor White
        Write-Host ""
        
        $existingChoice = Read-Host "Scelta [1-3]"
        
        switch ($existingChoice) {
            "1" {
                Write-Host "`nContinuo con import package + VPM setup..." -ForegroundColor Cyan
                $skipProjectCreation = $true
                $skipPackageImport = $false
            }
            "2" {
                Write-Host "`nContinuo solo con VPM setup..." -ForegroundColor Cyan
                $skipProjectCreation = $true
                $skipPackageImport = $true
            }
            "3" {
                Write-Host "`nOperazione annullata." -ForegroundColor Gray
                exit 0
            }
            default {
                Write-Host "`nScelta non valida, annullo operazione." -ForegroundColor Red
                exit 1
            }
        }
    } else {
        $skipProjectCreation = $false
        $skipPackageImport = $false
    }
    
    # Check Unity CLI esiste
    if (-not (Test-Path $UNITY_EDITOR_PATH)) {
        Write-Host "Errore: Unity Editor non trovato in: $UNITY_EDITOR_PATH" -ForegroundColor Red
        exit 1
    }
    
    # Creazione progetto (se necessario)
    if (-not $skipProjectCreation) {
        Write-Host "Creazione progetto: $packageName" -ForegroundColor Green
        Write-Host "Path: $newProjectPath" -ForegroundColor Gray
        Write-Host "Avvio Unity CLI... (puo' richiedere 1-2 minuti)" -ForegroundColor Yellow
        
        # Crea il progetto Unity con log file temporaneo
        $logFile = Join-Path $env:TEMP "unity-create-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
        Write-Host "Log: $logFile" -ForegroundColor Gray
        
        # Crea il progetto Unity in background per monitorare il progresso
        if ($Test) {
            Write-Host "[TEST] Would run Unity to create project: $newProjectPath" -ForegroundColor DarkGray
            Write-Host "[TEST] Would create log: $logFile" -ForegroundColor DarkGray
        } else {
            $process = Start-Process -FilePath $UNITY_EDITOR_PATH `
                -ArgumentList "-createProject `"$newProjectPath`" -quit -batchmode -logFile `"$logFile`"" `
                -NoNewWindow -PassThru
        }
        
        if (-not $Test) {
            # Mostra progresso con stats in tempo reale (one-liner dinamico)
            $startTime = Get-Date
            $lastLog = ""
            $lastStatsUpdate = Get-Date
            $cpuPercent = 0
            $memoryMB = 0
            
            # Salva posizione cursore iniziale
            $cursorTop = [Console]::CursorTop
            
            while (-not $process.HasExited) {
                Start-Sleep -Milliseconds 50
                
                # Calcola elapsed time
                $elapsed = (Get-Date) - $startTime
                $elapsedStr = "{0:mm}:{0:ss}" -f $elapsed
                
                # Get Unity process stats (solo ogni secondo per non sovraccaricare)
                if ((Get-Date) - $lastStatsUpdate -gt [TimeSpan]::FromSeconds(1)) {
                    try {
                        $unityProc = Get-Process -Id $process.Id -ErrorAction SilentlyContinue
                        if ($unityProc) {
                            $cpuPercent = [math]::Round($unityProc.CPU / $elapsed.TotalSeconds, 1)
                            $memoryMB = [math]::Round($unityProc.WorkingSet64 / 1MB, 0)
                        }
                    } catch { }
                    $lastStatsUpdate = Get-Date
                }
                
                # Leggi log SEMPRE per vedere aggiornamenti real-time
                if (Test-Path $logFile) {
                    $newLog = Get-Content $logFile -Tail 1 -ErrorAction SilentlyContinue
                    if ($newLog -and $newLog -ne $lastLog) {
                        $lastLog = $newLog
                    }
                }
                
                # Tronca il log dinamicamente in base alla larghezza finestra
                $maxLogLen = [Math]::Max(40, [Console]::WindowWidth - 50)
                $displayLog = if ($lastLog.Length -gt $maxLogLen) { 
                    $lastLog.Substring(0, $maxLogLen) + "..." 
                } else { 
                    $lastLog 
                }
                
                # Costruisci la stringa completa con padding
                $statusLine = "[Unity] $elapsedStr | CPU: $cpuPercent% | RAM: $($memoryMB)MB | $displayLog"
                $fullWidth = [Console]::WindowWidth - 1
                if ($statusLine.Length -gt $fullWidth) {
                    $statusLine = $statusLine.Substring(0, $fullWidth)
                } else {
                    $statusLine = $statusLine.PadRight($fullWidth)
                }
                
                # Riposiziona cursore e scrivi (evita newline)
                try {
                    [Console]::SetCursorPosition(0, $cursorTop)
                    [Console]::Write($statusLine)
                } catch {
                    # Fallback se il cursore non è posizionabile (es. resize)
                    $cursorTop = [Console]::CursorTop
                }
            }
            
            # Scrivi messaggio finale
            [Console]::SetCursorPosition(0, $cursorTop)
            $finalMsg = "[Unity] Completato! Tempo: $elapsedStr"
            Write-Host $finalMsg.PadRight([Console]::WindowWidth - 1) -ForegroundColor Green
            
            # Unity può uscire con exit code != 0 anche per warning o errori di compilazione
            # Verifichiamo invece che la cartella sia stata creata correttamente
            if ($process.ExitCode -ne 0) {
                Write-Host "Unity exit code: $($process.ExitCode) (potrebbe essere normale)" -ForegroundColor Yellow
            }
            
            # Check reale: verifica che Assets esista
            if (-not (Test-Path (Join-Path $newProjectPath "Assets"))) {
                Write-Host "Errore: progetto non creato correttamente" -ForegroundColor Red
                if (Test-Path $logFile) {
                    Write-Host "`nUltime righe del log:" -ForegroundColor Yellow
                    Get-Content $logFile -Tail 20
                }
                # Cleanup
                Write-Host "Pulizia cartella progetto fallito..." -ForegroundColor Yellow
                Remove-Item -Path $newProjectPath -Recurse -Force -ErrorAction SilentlyContinue
                exit 1
            }
        } else {
            Write-Host "[TEST] Skipped Unity create checks and progress monitoring" -ForegroundColor DarkGray
        }
        
        Write-Host "Progetto creato!" -ForegroundColor Green
    } else {
        Write-Host "Progetto già esistente, skip creazione." -ForegroundColor Yellow
    }
    
    # Importa il package principale (se richiesto)
    if (-not $skipPackageImport) {
        Write-Host "Importazione package: $packageName.unitypackage" -ForegroundColor Cyan
        Write-Host "Avvio Unity per import... (puo' richiedere 1-2 minuti)" -ForegroundColor Yellow
        
        $importLogFile = Join-Path $env:TEMP "unity-import-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
        
        if ($Test) {
            Write-Host "[TEST] Would start Unity to import package to project: $newProjectPath" -ForegroundColor DarkGray
            Write-Host "[TEST] Would create log: $importLogFile" -ForegroundColor DarkGray
        } else {
            $importProcess = Start-Process -FilePath $UNITY_EDITOR_PATH `
                -ArgumentList "-projectPath `"$newProjectPath`" -importPackage `"$projectPath`" -quit -batchmode -logFile `"$importLogFile`"" `
                -NoNewWindow -PassThru
        }
        
        if (-not $Test) {
            # Mostra progresso con stats in tempo reale (one-liner dinamico)
            $startTime = Get-Date
            $lastLog = ""
            $lastStatsUpdate = Get-Date
            $cpuPercent = 0
            $memoryMB = 0
            
            # Salva posizione cursore iniziale
            $cursorTop = [Console]::CursorTop
            
            while (-not $importProcess.HasExited) {
                Start-Sleep -Milliseconds 50
                
                # Calcola elapsed time
                $elapsed = (Get-Date) - $startTime
                $elapsedStr = "{0:mm}:{0:ss}" -f $elapsed
                
                # Get Unity process stats (solo ogni secondo)
                if ((Get-Date) - $lastStatsUpdate -gt [TimeSpan]::FromSeconds(1)) {
                    try {
                        $unityProc = Get-Process -Id $importProcess.Id -ErrorAction SilentlyContinue
                        if ($unityProc) {
                            $cpuPercent = [math]::Round($unityProc.CPU / $elapsed.TotalSeconds, 1)
                            $memoryMB = [math]::Round($unityProc.WorkingSet64 / 1MB, 0)
                        }
                    } catch { }
                    $lastStatsUpdate = Get-Date
                }
                
                # Leggi log SEMPRE per vedere aggiornamenti real-time
                if (Test-Path $importLogFile) {
                    $newLog = Get-Content $importLogFile -Tail 1 -ErrorAction SilentlyContinue
                    if ($newLog -and $newLog -ne $lastLog) {
                        $lastLog = $newLog
                    }
                }
                
                # Tronca il log dinamicamente in base alla larghezza finestra
                $maxLogLen = [Math]::Max(40, [Console]::WindowWidth - 50)
                $displayLog = if ($lastLog.Length -gt $maxLogLen) { 
                    $lastLog.Substring(0, $maxLogLen) + "..." 
                } else { 
                    $lastLog 
                }
                
                # Costruisci la stringa completa con padding
                $statusLine = "[Import] $elapsedStr | CPU: $cpuPercent% | RAM: $($memoryMB)MB | $displayLog"
                $fullWidth = [Console]::WindowWidth - 1
                if ($statusLine.Length -gt $fullWidth) {
                    $statusLine = $statusLine.Substring(0, $fullWidth)
                } else {
                    $statusLine = $statusLine.PadRight($fullWidth)
                }
                
                # Riposiziona cursore e scrivi (evita newline)
                try {
                    [Console]::SetCursorPosition(0, $cursorTop)
                    [Console]::Write($statusLine)
                } catch {
                    # Fallback se il cursore non è posizionabile (es. resize)
                    $cursorTop = [Console]::CursorTop
                }
            }
            
            # Scrivi messaggio finale
            [Console]::SetCursorPosition(0, $cursorTop)
            $finalMsg = "[Import] Completato! Tempo: $elapsedStr"
            Write-Host $finalMsg.PadRight([Console]::WindowWidth - 1) -ForegroundColor Green
            
            # Gli errori di compilazione sono normali quando si importano package
            # Verifichiamo solo che il processo sia terminato correttamente
            if ($importProcess.ExitCode -ne 0) {
                Write-Host "Unity exit code: $($importProcess.ExitCode) (errori di compilazione sono normali)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "[TEST] Skipped Unity import checks and progress monitoring" -ForegroundColor DarkGray
        }

        Write-Host "Package importato!" -ForegroundColor Green
    } else {
        Write-Host "Skip import package (progetto già esistente)." -ForegroundColor Yellow
    }
    
    # Aggiungi NUnit Test Framework (richiesto da VRChat SDK)
    $manifestPath = Join-Path $newProjectPath "Packages\manifest.json"
    if ((Test-Path $manifestPath) -and (-not $manifestBackedUp)) {
        try {
            $backupPath = "$manifestPath.bak.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Copy-Item $manifestPath -Destination $backupPath -Force
            Write-Host "Backup manifest created: $backupPath" -ForegroundColor Gray
            $manifestBackedUp = $true
        } catch {
            Write-Host "Failed to create manifest backup: $_" -ForegroundColor Yellow
        }
    }
    Install-NUnitPackage -ProjectPath $newProjectPath
    
    # Ora usa il nuovo progetto per il resto dello script
    $projectPath = $newProjectPath
}

# === MODALITÀ 2: Progetto esistente (comportamento originale) ===
# Check 3: È un progetto Unity (cerca Assets o Packages folder)
$assetsPath = Join-Path $projectPath "Assets"
$packagesPath = Join-Path $projectPath "Packages"

if (-not ((Test-Path $assetsPath) -or (Test-Path $packagesPath))) {
    Write-Host "Errore: non sembra un progetto Unity" -ForegroundColor Red
    Write-Host "Path: $projectPath" -ForegroundColor Yellow
    exit 1
}

# Vai al progetto
Push-Location $projectPath

$manifestBackedUp = $false

try {
    Write-Host "Installing VRC packages in: $projectPath" -ForegroundColor Green

    # Backup manifest before changes (covers Install-NUnitPackage too)
    $manifestPath = Join-Path $projectPath "Packages\manifest.json"
    if ((Test-Path $manifestPath) -and (-not $manifestBackedUp)) {
        try {
            $backupPath = "$manifestPath.bak.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Copy-Item $manifestPath -Destination $backupPath -Force
            Write-Host "Backup manifest created: $backupPath" -ForegroundColor Gray
            $manifestBackedUp = $true
        } catch {
            Write-Host "Failed to create manifest backup: $_" -ForegroundColor Yellow
        }
    }
    
    # Aggiungi NUnit Test Framework se mancante
    Install-NUnitPackage -ProjectPath $projectPath
    
    # Installa VPM packages dalla configurazione
    $manifestBackedUp = $false
    foreach ($pkg in $VPM_PACKAGES.PSObject.Properties) {
        $packageName = $pkg.Name
        $packageVersion = $pkg.Value
        
        Write-Host "Processing package: $packageName : $packageVersion" -ForegroundColor Cyan
        # Backup manifest before changes
        $manifestPath = Join-Path $projectPath "Packages\manifest.json"
        if ((Test-Path $manifestPath) -and (-not $manifestBackedUp)) {
            try {
                $backupPath = "$manifestPath.bak.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                Copy-Item $manifestPath -Destination $backupPath -Force
                Write-Host "Backup manifest created: $backupPath" -ForegroundColor Gray
                $manifestBackedUp = $true
            } catch {
                Write-Host "Failed to create manifest backup: $_" -ForegroundColor Yellow
            }
        }

        # Dry-run/Test mode support: only report actions
        if ($Test) {
            Write-Host "[TEST] Would add package: $packageName@$packageVersion" -ForegroundColor DarkGray
            Add-Content -Path $global:VRCSETUP_LOGFILE -Value "[TEST] Would add package: $packageName@$packageVersion"
            continue
        }

        # Execute vpm add and log the output
        try {
            if ($packageVersion -eq "latest") {
                Write-Host "Adding package: $packageName (latest)" -ForegroundColor Cyan
                vpm add package $packageName 2>&1 | Tee-Object -FilePath $global:VRCSETUP_LOGFILE -Append
            } else {
                Write-Host "Adding package: $packageName @ $packageVersion" -ForegroundColor Cyan
                vpm add package "$packageName@$packageVersion" 2>&1 | Tee-Object -FilePath $global:VRCSETUP_LOGFILE -Append
            }
            if ($LASTEXITCODE -ne 0) { Write-Host "vpm reported exit code $LASTEXITCODE for $packageName" -ForegroundColor Yellow }
        } catch {
            Write-Host "Failed to add $packageName: $_" -ForegroundColor Red
            Add-Content -Path $global:VRCSETUP_LOGFILE -Value "ERROR: Failed to add $packageName : $_"
        }
    }
    
    # Ensure manifest path is available for lockfile snapshot
    $manifestPath = Join-Path $projectPath "Packages\manifest.json"
    vpm resolve project $projectPath 2>&1 | Tee-Object -FilePath $global:VRCSETUP_LOGFILE -Append

    # Save a lightweight lock snapshot of the resulting manifest
    if (-not $Test) {
        $resolvedManifestPath = Join-Path $scriptDir "vrcsetup.lock.json"
        if (Test-Path $manifestPath) {
            Copy-Item $manifestPath -Destination $resolvedManifestPath -Force
            Write-Host "Saved lock manifest: $resolvedManifestPath" -ForegroundColor Gray
        }
    } else {
        Write-Host "[TEST] Skipped saving lock manifest (test mode)" -ForegroundColor DarkGray
    }
    
    Write-Host "`nSetup complete!" -ForegroundColor Green
} catch {
    Write-Host "`nErrore durante setup: $_" -ForegroundColor Red
    exit 1
} finally {
    Pop-Location
}
