# VRChat Setup Scripts

Script automatizzati per la creazione e configurazione di progetti VRChat Unity.

## 📦 Struttura

```
UNITY PROJECTS SCRIPT/
├── Setup Project.bat          # Launcher principale
└── setup-scripts/
    ├── vrcsetup-wizard.ps1    # Wizard interattivo
    ├── vrcsetupflowye.ps1     # Script principale
    └── vrcsetup.config        # Configurazione (generato al primo avvio)
```

## 🚀 Utilizzo

### Avvio Rapido

Esegui `Setup Project.bat` per aprire il wizard interattivo.

### Modalità Wizard

Il wizard offre le seguenti opzioni:

1. **Creare nuovo progetto da UnityPackage** - Crea un progetto Unity e importa un .unitypackage
2. **Setup VRChat su progetto esistente** - Aggiunge VPM packages a un progetto esistente
3. **Configura VPM packages** - Gestisci i pacchetti VPM e le loro versioni
4. **Reset configurazione** - Resetta la configurazione

### Modalità CLI

```powershell
# Crea progetto da UnityPackage
.\vrcsetupflowye.ps1 "C:\Path\To\Package.unitypackage"

# Setup su progetto esistente
.\vrcsetupflowye.ps1 "C:\Path\To\UnityProject"

# Reset configurazione
.\vrcsetupflowye.ps1 -reset
```

## ⚙️ Configurazione VPM Packages

### Formato Configurazione

I pacchetti VPM sono ora configurabili con versioni specifiche nel file `vrcsetup.config`:

```json
{
    "VpmPackages": {
        "com.vrchat.base": "latest",
        "com.vrchat.avatars": "3.5.0",
        "com.poiyomi.toon": "9.0.57",
        "com.vrcfury.vrcfury": "latest"
    },
    "UnityEditorPath": "C:\\Program Files\\Unity\\Hub\\Editor\\2022.3.22f1\\Editor\\Unity.exe",
    "UnityProjectsRoot": "F:\\UNITY PROJECTS"
}
```

### Gestione Versioni

- **`"latest"`** - Installa l'ultima versione disponibile
- **`"3.5.0"`** - Installa una versione specifica
- La validazione delle versioni avviene tramite `vpm show package <nome>`

### Operazioni Disponibili nel Wizard

Dal menu "Configura VPM packages" puoi:

- **Aggiungere package** - Specifica nome e versione (con validazione)
- **Modificare versione** - Cambia la versione di un package esistente
- **Rimuovere package** - Elimina un package dalla configurazione
- **Salvare** - Salva le modifiche nel file config

## 🔄 Migrazione da Vecchio Formato

Se hai una configurazione esistente con il vecchio formato (array di stringhe), lo script la convertirà automaticamente al nuovo formato con versioni:

```json
// VECCHIO FORMATO
"VpmPackages": ["com.vrchat.base", "com.vrchat.avatars"]

// NUOVO FORMATO (conversione automatica)
"VpmPackages": {
    "com.vrchat.base": "latest",
    "com.vrchat.avatars": "latest"
}
```

## 📝 Changelog

### v2.0 - 26/10/2025
- ✨ Aggiunto supporto versioni configurabili per VPM packages
- ✅ Validazione versioni tramite `vpm show package`
- 🔄 Migrazione automatica dal vecchio formato array
- 📋 Nuova opzione "Modifica versione package" nel wizard
- 💾 Salvataggio versioni nella configurazione

### v1.0
- 🎉 Release iniziale
- 📦 Supporto creazione progetti da UnityPackage
- ⚙️ Setup VRChat su progetti esistenti
- 🎮 Wizard interattivo
