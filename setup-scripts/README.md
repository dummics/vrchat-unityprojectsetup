# VRChat Unity Project Setup - Modular Scripts

Structure:
- `vrc-setup-script.ps1`: main unified entrypoint with `-projectPath` or `-Wizard` flags.
- `vrc-setup-script.ps1`: unified entrypoint with `-projectPath` or `-Wizard` flags.
- `commands/wrappers/`: optional legacy wrappers (vrcsetupscript.ps1, vrcsetup-wizard.ps1) kept for backward compatibility.
- `commands/installer.ps1`: `Start-Installer` and installer helpers (VPM package installation, Unity create/import).
- `commands/wizard.ps1`: `Start-Wizard` logic and menu.
- `lib/`: shared helpers: menu, config, progress, utils.
- `config/`: configuration and JSON files (vrcsetup.config, vrcsetup.lock.json).

- Next steps:
- Continue modularizing by moving more logic into `commands/installer.ps1` and splitting into smaller commands.
- Gradual translation of messages to English.
- Add more tests and CI checks for `-Test` dry-run mode.
- Archive/Remove legacy scripts in root after validating wrappers and main entrypoint.
	- Legacy scripts are archived in `archive/legacy` (if present).
