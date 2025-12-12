@echo off
:: VRChat Setup Wizard - Wrapper batch (uses main unified entrypoint)
powershell -ExecutionPolicy Bypass -File "%~dp0vrc-setup-script.ps1" -Wizard
pause
