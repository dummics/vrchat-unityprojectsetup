param([string]$projectPath, [switch]$Test, [switch]$Wizard)

# Top-level entry point for vrc setup
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "${scriptDir}\commands\wizard.ps1"
. "${scriptDir}\commands\installer.ps1"

if ($Wizard -or (-not $projectPath)) {
    Start-Wizard
    exit 0
}

Start-Installer -projectPath $projectPath -Test:$Test
