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

# Helper: interactive filterable menu (type-to-filter + arrows)
function Show-MenuFilter {
    param(
        [string]$Title = "",
        [string]$Header = "",
        [string[]]$Options,
        [string[]]$PinnedOptions = @(),
        [string]$Placeholder = "Type to filter...",
        [bool]$AllowCancel = $true,
        [int]$MaxVisible = 15,
        [bool]$EnterReturnsFilterWhenNoMatch = $true
    )

    if (-not $Options) { return $null }

    $filter = ""
    $current = 0

    while ($true) {
        $filterTokens = @()
        if (-not [string]::IsNullOrWhiteSpace($filter)) {
            $filterTokens = $filter.Split(@(' ',"\t"), [System.StringSplitOptions]::RemoveEmptyEntries)
        }

        $unfiltered = @($Options | Where-Object { $PinnedOptions -notcontains $_ })

        $matches = if ($filterTokens.Count -eq 0) {
            $unfiltered
        } else {
            $unfiltered | Where-Object {
                $candidate = $_
                $ok = $true
                foreach ($t in $filterTokens) {
                    if ($candidate -notlike "*${t}*") { $ok = $false; break }
                }
                $ok
            }
        }

        # Ensure pinned options are always visible on top (not affected by filter)
        $matches = @($PinnedOptions) + @($matches)

        if ($matches.Count -eq 0) {
            $current = 0
        } else {
            if ($current -lt 0) { $current = 0 }
            if ($current -ge $matches.Count) { $current = [Math]::Max(0, $matches.Count - 1) }
        }

        Clear-Host
        if ($Title) { Write-Host "`n${Title}`n" -ForegroundColor Cyan }
        if ($Header) { Write-Host "${Header}`n" -ForegroundColor Yellow }

        $filterLine = if ([string]::IsNullOrWhiteSpace($filter)) { $Placeholder } else { $filter }
        Write-Host ("Filter: {0}" -f $filterLine) -ForegroundColor Gray
        Write-Host ("Matches: {0}" -f ($matches.Count)) -ForegroundColor DarkGray
        Write-Host "" 

        $toShow = @($matches | Select-Object -First $MaxVisible)
        for ($i = 0; $i -lt $toShow.Count; $i++) {
            if ($i -eq $current) {
                Write-Host " > $($toShow[$i])" -ForegroundColor Yellow -BackgroundColor DarkGray
            } else {
                Write-Host "   $($toShow[$i])" -ForegroundColor White
            }
        }

        if ($matches.Count -gt $MaxVisible) {
            Write-Host "" 
            Write-Host ("... showing first {0} results" -f $MaxVisible) -ForegroundColor DarkGray
        }

        $keyInfo = [Console]::ReadKey($true)
        switch ($keyInfo.Key) {
            'UpArrow'   { if ($current -gt 0) { $current-- } }
            'DownArrow' { if ($current -lt ([Math]::Min($MaxVisible, $matches.Count) - 1)) { $current++ } }
            'Enter' {
                if ($matches.Count -eq 0) {
                    if ($EnterReturnsFilterWhenNoMatch -and (-not [string]::IsNullOrWhiteSpace($filter))) {
                        return $filter
                    }
                    continue
                }

                $firstPage = ($matches | Select-Object -First $MaxVisible)
                return $firstPage[$current]
            }
            'Escape' { if ($AllowCancel) { return $null } }
            'Backspace' {
                if ($filter.Length -gt 0) {
                    $filter = $filter.Substring(0, $filter.Length - 1)
                    $current = 0
                }
            }
            default {
                $c = $keyInfo.KeyChar
                if ($c -and (-not [char]::IsControl($c))) {
                    $filter += $c
                    $current = 0
                }
            }
        }
    }
}

