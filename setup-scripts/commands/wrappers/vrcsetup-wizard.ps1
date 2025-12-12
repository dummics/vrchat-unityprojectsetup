param()

$cmdDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptDir = (Resolve-Path (Join-Path $cmdDir '..')).Path
. "${scriptDir}\commands\wizard.ps1"
. "${scriptDir}\commands\installer.ps1"
. "${scriptDir}\lib\config.ps1"
Start-Wizard
exit 0
