# lib/config.ps1 - simple config helpers
function Load-Config {
    param([string]$ConfigPath)
    if (-not $ConfigPath) { throw 'ConfigPath is required' }
    if (-not (Test-Path $ConfigPath)) { return $null }
    return Get-Content $ConfigPath -Raw | ConvertFrom-Json
}

function Save-Config {
    param([PSCustomObject]$Config, [string]$ConfigPath)
    if (-not $ConfigPath) { throw 'ConfigPath required' }
    $Config | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath -Encoding UTF8
    Write-Host "Configuration saved to: ${ConfigPath}" -ForegroundColor Green
}

Export-ModuleMember -Function Load-Config, Save-Config
