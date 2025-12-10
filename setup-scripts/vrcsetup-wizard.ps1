# VRChat Setup Wizard - Interfaccia semplificata
# Questo script guida l'utente passo passo senza bisogno di parametri complicati

# === FUNZIONI ===
function Initialize-VpmTestProject {
    param([string]$ScriptDir)
    
    $testProjectPath = Join-Path $ScriptDir ".vpm-validation-cache"
    
    # Se esiste già, usalo
    if (Test-Path $testProjectPath) {
        return $testProjectPath
    }
    
    Write-Host "Inizializzazione cache validazione VPM (solo prima volta)..." -ForegroundColor Yellow
    
    # Crea cartella vuota
    New-Item -ItemType Directory -Path $testProjectPath -Force | Out-Null
    
    # Crea struttura minimale progetto Unity/VPM
    $packagesPath = Join-Path $testProjectPath "Packages"
    New-Item -ItemType Directory -Path $packagesPath -Force | Out-Null
    
    # Crea manifest.json minimale
    $manifest = @{
        dependencies = @{}
    }
    $manifest | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $packagesPath "manifest.json") -Encoding UTF8
    
    # Crea vpm-manifest.json minimale
    $vpmManifest = @{
        dependencies = @{}
        locked = @{}
    }
    $vpmManifest | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $packagesPath "vpm-manifest.json") -Encoding UTF8
    
    Write-Host "Cache creata in: $testProjectPath" -ForegroundColor Green
    
    return $testProjectPath
}

function Test-VpmPackageVersion {
    param(
        [string]$PackageName,
        [string]$Version,
        [string]$ScriptDir
    )
    
    # Se la versione è "latest", è sempre valida
    if ($Version -eq "latest") {
        return @{ Valid = $true; Message = "Versione 'latest' sempre valida" }
    }
    
    Write-Host "Validazione $PackageName@$Version..." -ForegroundColor Gray
    
    # Inizializza progetto test se necessario
    $testProject = Initialize-VpmTestProject -ScriptDir $ScriptDir
    
    # Testa l'aggiunta del package con vpm
    try {
        $packageSpec = "$PackageName@$Version"
        $output = vpm add package $packageSpec -p $testProject 2>&1 | Out-String
        
        # Check se c'è errore
        if ($output -match "ERR.*Could not get match" -or $output -match "ERR.*not found") {
            # Estrai versioni disponibili dai repository locali
            $reposPath = "$env:LOCALAPPDATA\VRChatCreatorCompanion\Repos"
            $availableVersions = @()
            
            if (Test-Path $reposPath) {
                Get-ChildItem $reposPath -Filter "*.json" -ErrorAction SilentlyContinue | ForEach-Object {
                    try {
                        $repoData = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
                        if ($repoData.packages.$PackageName) {
                            $versions = $repoData.packages.$PackageName.versions.PSObject.Properties.Name
                            if ($versions) {
                                $availableVersions += $versions
                            }
                        }
                    } catch { }
                }
            }
            
            if ($availableVersions.Count -gt 0) {
                $sortedVersions = $availableVersions | Sort-Object -Descending | Select-Object -First 5
                $versionList = $sortedVersions -join ", "
                return @{ 
                    Valid = $false
                    Message = "Versione $Version non trovata. Ultime disponibili: $versionList"
                }
            }
            
            return @{ Valid = $false; Message = "Versione $Version non disponibile" }
        }
        
        # Se non ci sono errori, la versione è valida
        Write-Host "Versione valida!" -ForegroundColor Green
        
        # Rimuovi il package dal progetto test per mantenerlo pulito
        vpm remove package $PackageName -p $testProject 2>&1 | Out-Null
        
        return @{ Valid = $true; Message = "Versione verificata con VPM" }
        
    } catch {
        Write-Host "Errore durante validazione: $_" -ForegroundColor Red
        return @{ Valid = $false; Message = "Errore durante validazione VPM" }
    }
}

# === CARICAMENTO CONFIG ===
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$vrcsetupScript = Join-Path $scriptDir "vrcsetupscript.ps1"

# Header
Write-Host "`n================================" -ForegroundColor Cyan
Write-Host "   VRChat Project Setup Wizard" -ForegroundColor Cyan
Write-Host "================================`n" -ForegroundColor Cyan

# Verifica che lo script principale esista
if (-not (Test-Path $vrcsetupScript)) {
    Write-Host "Errore: vrcsetupflowye.ps1 non trovato nella stessa cartella!" -ForegroundColor Red
    Read-Host "Premi INVIO per uscire"
    exit 1
}

# Menu principale
while ($true) {
    Clear-Host
    Write-Host "`nCosa vuoi fare?" -ForegroundColor Yellow
    Write-Host "  1) Creare nuovo progetto da UnityPackage" -ForegroundColor White
    Write-Host "  2) Setup VRChat su progetto esistente" -ForegroundColor White
    Write-Host "  3) Configura VPM packages" -ForegroundColor White
    Write-Host "  4) Reset configurazione" -ForegroundColor White
    Write-Host "  5) Esci" -ForegroundColor White
    Write-Host ""
    
    $choice = Read-Host "Scelta [1-5]"
    
    # Gestisci input vuoto
    if ([string]::IsNullOrWhiteSpace($choice)) {
        continue
    }
    
    switch ($choice) {
        "1" {
            Clear-Host
            # Creazione da UnityPackage
            Write-Host "`n--- Creazione progetto da UnityPackage ---" -ForegroundColor Cyan
            Write-Host "Trascina qui il file .unitypackage (o incolla il path completo):" -ForegroundColor Yellow
            Write-Host "(Premi INVIO per annullare)" -ForegroundColor Gray
            $packagePath = Read-Host "Path UnityPackage"
            
            # Check annullamento
            if ([string]::IsNullOrWhiteSpace($packagePath)) {
                Write-Host "Operazione annullata." -ForegroundColor Yellow
                Start-Sleep -Seconds 1
                continue
            }
            
            # Rimuovi virgolette se presenti (quando trascini file)
            $packagePath = $packagePath.Trim('"')
            
            if (-not (Test-Path $packagePath)) {
                Write-Host "`nErrore: file non trovato!" -ForegroundColor Red
                Read-Host "Premi INVIO per continuare"
                Clear-Host
                continue
            }
            
            if ($packagePath -notlike "*.unitypackage") {
                Write-Host "`nErrore: il file deve essere un .unitypackage!" -ForegroundColor Red
                Read-Host "Premi INVIO per continuare"
                Clear-Host
                continue
            }
            
            Write-Host "`nAvvio creazione progetto..." -ForegroundColor Green
            & $vrcsetupScript $packagePath
            
            Write-Host "`n--- Operazione completata ---" -ForegroundColor Green
            Read-Host "Premi INVIO per tornare al menu"
            Clear-Host
        }
        
        "2" {
            Clear-Host
            # Setup progetto esistente
            Write-Host "`n--- Setup VRChat su progetto esistente ---" -ForegroundColor Cyan
            Write-Host "Trascina qui la cartella del progetto Unity (o incolla il path):" -ForegroundColor Yellow
            Write-Host "(Premi INVIO per annullare)" -ForegroundColor Gray
            $projectPath = Read-Host "Path Progetto"
            
            # Check annullamento
            if ([string]::IsNullOrWhiteSpace($projectPath)) {
                Write-Host "Operazione annullata." -ForegroundColor Yellow
                Start-Sleep -Seconds 1
                continue
            }
            
            # Rimuovi virgolette se presenti
            $projectPath = $projectPath.Trim('"')
            
            if (-not (Test-Path $projectPath)) {
                Write-Host "`nErrore: cartella non trovata!" -ForegroundColor Red
                Read-Host "Premi INVIO per continuare"
                Clear-Host
                continue
            }
            
            # Verifica che sia un progetto Unity
            $assetsPath = Join-Path $projectPath "Assets"
            if (-not (Test-Path $assetsPath)) {
                Write-Host "`nErrore: non sembra un progetto Unity (manca la cartella Assets)!" -ForegroundColor Red
                Read-Host "Premi INVIO per continuare"
                Clear-Host
                continue
            }
            
            Write-Host "`nAvvio setup VRChat..." -ForegroundColor Green
            & $vrcsetupScript $projectPath
            
            Write-Host "`n--- Operazione completata ---" -ForegroundColor Green
            Read-Host "Premi INVIO per tornare al menu"
            Clear-Host
        }
        
        "3" {
            Clear-Host
            # Configurazione VPM packages
            $configPath = Join-Path $scriptDir "vrcsetup.config"
            
            if (-not (Test-Path $configPath)) {
                Write-Host "`nErrore: devi prima creare un progetto per inizializzare la configurazione!" -ForegroundColor Red
                Read-Host "Premi INVIO per continuare"
                Clear-Host
                continue
            }
            
            $config = Get-Content $configPath -Raw | ConvertFrom-Json
            
            # Converti vecchio formato array a nuovo formato hashtable
            if ($config.VpmPackages -is [System.Array]) {
                Write-Host "`nConversione formato packages..." -ForegroundColor Yellow
                $newPackages = @{}
                foreach ($pkg in $config.VpmPackages) {
                    $newPackages[$pkg] = "latest"
                }
                $config.VpmPackages = $newPackages
            }
            
            # Inizializza se non esiste
            if (-not $config.VpmPackages) {
                $config | Add-Member -MemberType NoteProperty -Name "VpmPackages" -Value @{
                    "com.vrchat.base" = "latest"
                    "com.vrchat.avatars" = "latest"
                    "com.poiyomi.toon" = "latest"
                    "adjerry91.vrcft.templates" = "latest"
                    "com.vrcfury.vrcfury" = "latest"
                    "gogoloco" = "latest"
                    "com.vrchat.core.vpm-resolver" = "latest"
                }
            }
            
            $exitVpmMenu = $false
            while (-not $exitVpmMenu) {
                Clear-Host
                Write-Host "`n--- Configurazione VPM Packages ---" -ForegroundColor Cyan
                Write-Host "Packages attualmente configurati:" -ForegroundColor Yellow
                
                $i = 0
                $packagesList = @()
                foreach ($pkg in $config.VpmPackages.PSObject.Properties) {
                    $i++
                    $packagesList += $pkg
                    Write-Host "  $i) $($pkg.Name) @ $($pkg.Value)" -ForegroundColor White
                }
                
                Write-Host "`nOpzioni:" -ForegroundColor Yellow
                Write-Host "  A) Aggiungi package" -ForegroundColor White
                Write-Host "  E) Modifica versione package" -ForegroundColor White
                Write-Host "  R) Rimuovi package" -ForegroundColor White
                Write-Host "  S) Salva e torna al menu" -ForegroundColor White
                Write-Host ""
                
                $vpmChoice = Read-Host "Scelta [A/E/R/S]"
                
                # Gestisci input vuoto
                if ([string]::IsNullOrWhiteSpace($vpmChoice)) {
                    Write-Host "Input vuoto, riprova!" -ForegroundColor Red
                    Start-Sleep -Seconds 1
                    continue
                }
                
                switch ($vpmChoice.ToUpper().Trim()) {
                    "A" {
                        Write-Host "`nInserisci il nome del package VPM da aggiungere:" -ForegroundColor Yellow
                        Write-Host "(es. com.vrchat.avatars oppure gogoloco per package semplici)" -ForegroundColor Gray
                        $newPackage = Read-Host "Nome package"
                        
                        if ([string]::IsNullOrWhiteSpace($newPackage)) {
                            Write-Host "Nome package vuoto, operazione annullata." -ForegroundColor Yellow
                            continue
                        }
                        
                        if ($config.VpmPackages.PSObject.Properties.Name -contains $newPackage) {
                            Write-Host "Package già presente nella lista!" -ForegroundColor Yellow
                            continue
                        }
                        
                        Write-Host "`nInserisci la versione (o 'latest' per l'ultima disponibile):" -ForegroundColor Yellow
                        Write-Host "Esempi: 3.5.0, 1.0.0, latest" -ForegroundColor Gray
                        $newVersion = Read-Host "Versione"
                        
                        if ([string]::IsNullOrWhiteSpace($newVersion)) {
                            $newVersion = "latest"
                            Write-Host "Nessuna versione specificata, uso 'latest'" -ForegroundColor Gray
                        }
                        
                        # Valida la versione
                        $validation = Test-VpmPackageVersion -PackageName $newPackage -Version $newVersion -ScriptDir $scriptDir
                        if ($validation.Valid) {
                            $config.VpmPackages | Add-Member -MemberType NoteProperty -Name $newPackage -Value $newVersion -Force
                            Write-Host "Package aggiunto: $newPackage @ $newVersion" -ForegroundColor Green
                            Write-Host "($($validation.Message))" -ForegroundColor Gray
                        } else {
                            Write-Host "Errore: $($validation.Message)" -ForegroundColor Red
                            Write-Host "Package non aggiunto." -ForegroundColor Yellow
                        }
                    }
                    
                    "E" {
                        if ($packagesList.Count -eq 0) {
                            Write-Host "`nNessun package da modificare!" -ForegroundColor Yellow
                            continue
                        }
                        
                        Write-Host "`nInserisci il numero del package da modificare:" -ForegroundColor Yellow
                        $modifyIdx = Read-Host "Numero"
                        
                        if ([string]::IsNullOrWhiteSpace($modifyIdx)) {
                            Write-Host "Operazione annullata." -ForegroundColor Yellow
                            continue
                        }
                        
                        try {
                            $idx = [int]$modifyIdx - 1
                            if ($idx -ge 0 -and $idx -lt $packagesList.Count) {
                                $pkgToModify = $packagesList[$idx]
                                Write-Host "`nPackage selezionato: $($pkgToModify.Name) (versione attuale: $($pkgToModify.Value))" -ForegroundColor Cyan
                                Write-Host "Inserisci la nuova versione (o 'latest'):" -ForegroundColor Yellow
                                Write-Host "Premi INVIO per annullare" -ForegroundColor Gray
                                $newVersion = Read-Host "Nuova versione"
                                
                                if ([string]::IsNullOrWhiteSpace($newVersion)) {
                                    Write-Host "Operazione annullata." -ForegroundColor Yellow
                                    continue
                                }
                                
                                # Valida la versione
                                $validation = Test-VpmPackageVersion -PackageName $pkgToModify.Name -Version $newVersion -ScriptDir $scriptDir
                                if ($validation.Valid) {
                                    $config.VpmPackages.($pkgToModify.Name) = $newVersion
                                    Write-Host "Versione aggiornata: $($pkgToModify.Name) @ $newVersion" -ForegroundColor Green
                                    Write-Host "($($validation.Message))" -ForegroundColor Gray
                                } else {
                                    Write-Host "Errore: $($validation.Message)" -ForegroundColor Red
                                    Write-Host "Modifica annullata." -ForegroundColor Yellow
                                }
                            } else {
                                Write-Host "Numero non valido! Scegli tra 1 e $($packagesList.Count)" -ForegroundColor Red
                            }
                        } catch {
                            Write-Host "Input non valido! Inserisci un numero." -ForegroundColor Red
                        }
                    }
                    
                    "R" {
                        if ($packagesList.Count -eq 0) {
                            Write-Host "`nNessun package da rimuovere!" -ForegroundColor Yellow
                            continue
                        }
                        
                        Write-Host "`nInserisci il numero del package da rimuovere:" -ForegroundColor Yellow
                        $removeIdx = Read-Host "Numero"
                        
                        if ([string]::IsNullOrWhiteSpace($removeIdx)) {
                            Write-Host "Operazione annullata." -ForegroundColor Yellow
                            continue
                        }
                        
                        try {
                            $idx = [int]$removeIdx - 1
                            if ($idx -ge 0 -and $idx -lt $packagesList.Count) {
                                $removed = $packagesList[$idx]
                                $config.VpmPackages.PSObject.Properties.Remove($removed.Name)
                                Write-Host "Package rimosso: $($removed.Name)" -ForegroundColor Green
                            } else {
                                Write-Host "Numero non valido! Scegli tra 1 e $($packagesList.Count)" -ForegroundColor Red
                            }
                        } catch {
                            Write-Host "Input non valido! Inserisci un numero." -ForegroundColor Red
                        }
                    }
                    
                    "S" {
                        # Salva configurazione
                        $configData = @{
                            UnityProjectsRoot = $config.UnityProjectsRoot
                            UnityEditorPath = $config.UnityEditorPath
                            VpmPackages = $config.VpmPackages
                        }
                        $configData | ConvertTo-Json | Set-Content $configPath -Encoding UTF8
                        Write-Host "`nConfigurazione salvata con successo!" -ForegroundColor Green
                        Start-Sleep -Seconds 1
                        $exitVpmMenu = $true
                    }
                    
                    default {
                        Write-Host "Scelta non valida! Usa A, E, R o S." -ForegroundColor Red
                    }
                }
            }
            
            Read-Host "`nPremi INVIO per tornare al menu principale"
            Clear-Host
        }
        
        "4" {
            Clear-Host
            # Reset configurazione
            Write-Host "`n--- Reset Configurazione ---" -ForegroundColor Cyan
            Write-Host "Sei sicuro di voler resettare la configurazione?" -ForegroundColor Yellow
            Write-Host "(Premi INVIO per annullare)" -ForegroundColor Gray
            $confirm = Read-Host "Conferma [s/n]"
            
            if ([string]::IsNullOrWhiteSpace($confirm) -or $confirm.ToLower() -ne "s") {
                Write-Host "Reset annullato." -ForegroundColor Gray
                Start-Sleep -Seconds 1
            } else {
                & $vrcsetupScript "-reset"
                Read-Host "Premi INVIO per continuare"
            }
        }
        
        "5" {
            Write-Host "`nArrivederci! :)" -ForegroundColor Cyan
            exit 0
        }
        
        default {
            Write-Host "`nScelta non valida! Riprova." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}
