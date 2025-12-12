# Helper: interactive menu with arrow keys and number keys support
function Show-Menu {
    param(
        [string]$Title = "",
        [string]$Header = "",
        [string[]]$Options,
        [int]$Current = 0,
        [bool]$AllowCancel = $true
    )

    if (-not $Options) { return -1 }

    while ($true) {
        Clear-Host
        if ($Title) { Write-Host "`n${Title}`n" -ForegroundColor Cyan }
        if ($Header) { Write-Host "${Header}`n" -ForegroundColor Yellow }

        for ($i = 0; $i -lt $Options.Count; $i++) {
            if ($i -eq $Current) {
                Write-Host " > $($Options[$i])" -ForegroundColor Yellow -BackgroundColor DarkGray
            } else {
                Write-Host "   $($Options[$i])" -ForegroundColor White
            }
        }

        $keyInfo = [Console]::ReadKey($true)

        # Handle arrow keys
        switch ($keyInfo.Key) {
            'UpArrow'    { if ($Current -gt 0) { $Current-- } }
            'DownArrow'  { if ($Current -lt ($Options.Count - 1)) { $Current++ } }
            'Enter'      { return $Current }
            'Escape'     { if ($AllowCancel) { return -1 } }
            default {
                # Support numeric selection (1..9 and numpad)
                $char = $keyInfo.KeyChar
                if ([char]::IsDigit($char)) {
                    try {
                        $digit = [int]$char
                        if ($digit -gt 0 -and $digit -le $Options.Count) {
                            return ($digit - 1)
                        }
                    } catch { }
                }
            }
        }
    }
}

Export-ModuleMember -Function Show-Menu
