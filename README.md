# VRChat Unity Project Setup Scripts

Automated scripts to create and configure VRChat Unity projects, add VPM packages, and manage setup workflows.

## 🎯 Purpose

This folder contains a set of scripts that help you quickly create, configure, and maintain VRChat Unity projects, including support for importing Unity packages and managing VPM packages/versions.

## 📦 Structure

```
UNITY PROJECTS SCRIPT/
├── vrcsetupfull.bat        # Launcher or entry point
└── setup-scripts/
    ├── vrcsetup-wizard.ps1 # Interactive setup wizard
    ├── vrcsetupflowye.ps1  # Main setup automation script
    └── vrcsetup.config     # Generated configuration file at first run
```

## 🚀 Quickstart

Run the script from PowerShell or via `vrcsetupfull.bat` to open the interactive wizard:

```powershell
# In PowerShell
.\setup-scripts\vrcsetupflowye.ps1

# Or execute the top-level .bat (Windows)
vrcsetupfull.bat
```

## 🧭 Modes of Operation

### Wizard Mode
The wizard offers the following options:

1. Create a new Unity project from a `.unitypackage` and import it.
2. Configure VRChat on an existing Unity project by adding required VPM packages.
3. Manage VPM packages and their versions (Add/Change/Remove packages).
4. Reset the configuration to defaults.

### CLI Mode
You can run the main script in scripted mode from command line:

```powershell
# Create project from UnityPackage
.\setup-scripts\vrcsetupflowye.ps1 "C:\Path\To\Package.unitypackage"

# Setup an existing project
.\setup-scripts\vrcsetupflowye.ps1 "C:\Path\To\UnityProject"

# Reset configuration
.\setup-scripts\vrcsetupflowye.ps1 -reset
```

## ⚙️ VPM Packages Configuration

The VPM packages included in the project are configurable in `vrcsetup.config` using package names and versions.

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
- The script validates versions with `vpm show package <package_name>`.

## 🔄 Migration from Old Format
Older config files that used a simple array of package names are migrated automatically into the new dict format with `latest` as a default version.

## 📝 Changelog (summary)

- v2.0 - 26/10/2025: Added support for configurable package versions, migration, and validation.
- v1.0: Initial release with .unitypackage-based setup, VPM configuration, and interactive wizard.

## 🛠️ Advanced Notes

- The script integrates with Unity via the editor path configured in the `vrcsetup.config` file.
- Ensure PowerShell execution policies and system permissions allow the script to invoke Unity and modify project files.

## Contributing

Contributions are welcome. Open an issue or a pull request with a description of the change.

## License
See the `LICENSE` file in this folder for license details.
