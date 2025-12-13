@echo off
:: VRChat Setup Wizard - Wrapper batch (uses main unified entrypoint)
setlocal

:: Prefer PowerShell 7 (pwsh) if available, fallback to Windows PowerShell.
where pwsh >nul 2>nul
if %errorlevel%==0 (
	set "PS_EXE=pwsh"
) else (
	set "PS_EXE=powershell"
)

:: Launch wizard in a NEW window, then close this terminal.
start "VRChat Setup Wizard" %PS_EXE% -NoProfile -ExecutionPolicy Bypass -NoExit -File "%~dp0vrc-setup-script.ps1" -Wizard
exit /b 0
