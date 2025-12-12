Helpers for vrcsetup scripts
 - `menu.ps1`: exports `Show-Menu` function that presents an interactive menu with arrow key navigation and numeric selection.
 - `utils.ps1`: exports `Install-NUnitPackage` helper function.
 - `config.ps1`: exports `Load-Config` and `Save-Config` helper functions.

Usage:
 Dot-source the helpers in your script to use functions:
 . "${scriptDir}\lib\menu.ps1"
 . "${scriptDir}\lib\utils.ps1"
