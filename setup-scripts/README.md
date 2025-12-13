# VRChat Unity Project Setup - Modular Scripts

Structure:
- `vrc-setup-script.ps1`: main unified entrypoint with `-projectPath` or `-Wizard` flags.
- `commands/wrappers/`: optional legacy wrappers (vrcsetupscript.ps1, vrcsetup-wizard.ps1) kept for backward compatibility.
- `commands/installer.ps1`: `Start-Installer` + helpers (UnityPackage create/import + VPM install).
- `commands/wizard.ps1`: `Start-Wizard` logic and menu.
- `lib/`: shared helpers: menu, config, progress, utils.
- `config/`: configuration and JSON files (vrcsetup.json, vrcsetup.lock.json).

Wizard UX notes:
- Main menu uses arrow-key selection.
- "Setup project" is unified: choose UnityPackage or existing project.
- VPM packages editor is 2-step: select package → choose action (change version/remove), plus add package (type-to-filter).
- Bugfix: "Add package" no longer throws and instantly returns to the list.
- Versions list is SemVer-sorted (e.g. 0.1.29 > 0.1.9).
- Version picker supports paging + filter patterns (e.g. *.9, X.X.1190, or re:<regex>).
- Advanced settings includes naming rules (prefix/suffix/regex remove) and per-unitypackage remembered project names.

Optional tooling:
- If a local `vrc-get` exe is present, the wizard can search packages and list versions even when the local VCC repos cache is empty.
	- Put the exe under `setup-scripts/lib/vrc-get/` (any `*.exe` name; `vrc-get.exe` preferred)

- Next steps:
- Continue modularizing by moving more logic into `commands/installer.ps1` and splitting into smaller commands.
- Gradual translation of messages to English.
- Add more tests and CI checks for `-Test` dry-run mode.
- Archive/Remove legacy scripts in root after validating wrappers and main entrypoint.
	- Legacy scripts are archived in `archive/legacy` (if present).
