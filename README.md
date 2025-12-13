# VRChat Unity Project Setup Scripts

Automated scripts to create and configure VRChat Unity projects, add VPM packages, and manage setup workflows.

## 🎯 Purpose

This folder contains a set of scripts that help you quickly create, configure, and maintain VRChat Unity projects, including support for importing Unity packages and managing VPM packages/versions.

## 📦 Structure

```
_unityprojectsetup/
├── vrcsetupfull.bat            # Launcher (opens the wizard)
└── setup-scripts/
    ├── vrc-setup-script.ps1    # Unified entrypoint (wizard + CLI)
    ├── setup.bat               # Batch wrapper for the wizard
    ├── commands/               # Wizard + installer commands
    ├── lib/                    # Shared helpers (menu/config/progress/utils)
    └── config/vrcsetup.json    # Configuration (generated/edited via wizard)
```

## 🚀 Quickstart

Run the script from PowerShell or via `vrcsetupfull.bat` to open the interactive wizard:

```powershell
# In PowerShell
.\setup-scripts\vrc-setup-script.ps1 -Wizard

# Or execute the top-level .bat (Windows)
vrcsetupfull.bat
```

## 🧭 Modes of Operation

### Wizard Mode
The wizard offers the following options:

1. Setup project (choose UnityPackage or existing project folder).
2. Manage VPM packages (type-to-filter picker + selectable versions when available).
3. Advanced settings (naming rules + remembered project names).
4. Reset the configuration.

### CLI Mode
You can run the main script in scripted mode from command line:

```powershell
# Create project from UnityPackage
.\setup-scripts\vrc-setup-script.ps1 -projectPath "C:\Path\To\Package.unitypackage"

# Setup an existing project
.\setup-scripts\vrc-setup-script.ps1 -projectPath "C:\Path\To\UnityProject"

# Reset configuration
.\setup-scripts\vrc-setup-script.ps1 -projectPath "-reset"
```

## ⚙️ VPM Packages Configuration

The VPM packages included in the project are configurable in `setup-scripts/config/vrcsetup.json` using package names and versions.

Example config snippet:

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

- `latest` installs the newest version available.
- You can specify exact versions like `"3.5.0"` to lock to a specific release.
- The wizard validates versions with VPM (fail-fast) and can also show selectable versions from the local VCC repos cache.

## 🧠 Advanced naming

In `setup-scripts/config/vrcsetup.json` you can store naming preferences used when creating a project from a UnityPackage:

- Prefix/suffix
- Regex remove patterns (auto-clean the suggested project name)
- Remember a custom project name per UnityPackage path

## 🔄 Migration from Old Format
Older config files that used a simple array of package names are migrated automatically into the new dict format with `latest` as a default version.

## 📝 Changelog (summary)

- v2.0 - 26/10/2025: Added support for configurable package versions, migration, and validation.
- v1.0: Initial release with .unitypackage-based setup, VPM configuration, and interactive wizard.

## 🛠️ Advanced Notes

- The script integrates with Unity via the editor path configured in `setup-scripts/config/vrcsetup.json`.
- Drag & drop inputs often include quotes; paths are normalized automatically.
- UnityPackage mode lets you override the project name; the wizard remembers the last one.
- Ensure PowerShell execution policies and system permissions allow the script to invoke Unity and modify project files.

### 🔍 Test mode, backups & logs

- `-Test` (dry-run): Run the script with `-Test` to print actions that would be performed without modifying the project or adding packages. Example:
```powershell
.\setup-scripts\vrc-setup-script.ps1 -projectPath "C:\Path\To\Project" -Test
```
- Backup: Before applying changes to `Packages/manifest.json`, the script creates a timestamped backup (`manifest.json.bak.YYYYMMDD-HHmmss`) in the same folder. If a change breaks the project, restore the original with:
```powershell
Copy-Item "<Project>\Packages\manifest.json.bak.YYYYMMDD-HHmmss" "<Project>\Packages\manifest.json" -Force
```
- Logs: the script writes `vpm` and execution logs to `setup-scripts/logs/` as `vrcsetup-YYYYMMDD-HHmmss.log`.

These features provide safe rollback paths without forcing any particular version policy. Keep in mind: we don't change versions automatically; pinning/upgrade decisions are still yours to set in `setup-scripts/config/vrcsetup.json`.

## Contributing

Contributions are welcome. Open an issue or a pull request with a description of the change.

## License
See the `LICENSE` file in this folder for license details.
