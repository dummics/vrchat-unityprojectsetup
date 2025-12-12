param([string]$projectPath, [switch]$Test)

$cmdDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptDir = (Resolve-Path (Join-Path $cmdDir '..')).Path
. "${scriptDir}\commands\installer.ps1"
. "${scriptDir}\lib\config.ps1"

# Delegate to Start-Installer implemented in commands/installer.ps1
$status = Start-Installer -projectPath $projectPath -Test:$Test
exit $status
