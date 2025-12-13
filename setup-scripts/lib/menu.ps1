# Helper: interactive menu with arrow keys and number keys support

function Test-VtSupported {
    # IMPORTANT: VT is opt-in.
    # Some hosts (es. PowerShell Extension / vecchia console) mostrano le escape come testo ("e[H...").
    # Set `VRCSETUP_TUI_VT=1` solo se sai che il tuo terminale le supporta.
    if ($env:VRCSETUP_TUI_VT -ne '1') { return $false }

    try {
        $ui = $Host.UI
        if ($ui -and ($ui | Get-Member -Name SupportsVirtualTerminal -MemberType Property -ErrorAction SilentlyContinue)) {
            return [bool]$ui.SupportsVirtualTerminal
        }
    } catch { }

    # Heuristic fallback for older hosts
    if (-not [string]::IsNullOrWhiteSpace($env:WT_SESSION)) { return $true }
    if (-not [string]::IsNullOrWhiteSpace($env:TERM) -and $env:TERM -ne 'dumb') { return $true }
    return $false
}

function Get-TuiTheme {
    return @{
        TitleFg     = 'Cyan'
        HeaderFg    = 'Gray'
        OptionFg    = 'White'
        SelectedFg  = 'Black'
        SelectedBg  = 'DarkCyan'
        MutedFg     = 'DarkGray'
        InputFg     = 'Gray'
    }
}

function Get-ConsoleWidthSafe {
    try {
        $w = [Console]::WindowWidth
        if ($w -gt 0) { return $w }
    } catch { }
    return 120
}

function Write-ConsoleAt {
    param(
        [int]$Left,
        [int]$Top,
        [string]$Text,
        [ConsoleColor]$ForegroundColor,
        [ConsoleColor]$BackgroundColor,
        [switch]$ClearToEnd
    )

    $oldFg = [Console]::ForegroundColor
    $oldBg = [Console]::BackgroundColor
    try {
        [Console]::SetCursorPosition([Math]::Max(0, $Left), [Math]::Max(0, $Top))
    } catch {
        return
    }

    try {
        if ($PSBoundParameters.ContainsKey('ForegroundColor')) { [Console]::ForegroundColor = $ForegroundColor }
        if ($PSBoundParameters.ContainsKey('BackgroundColor')) { [Console]::BackgroundColor = $BackgroundColor }

        $out = if ($null -eq $Text) { "" } else { [string]$Text }
        if ($ClearToEnd) {
            $w = Get-ConsoleWidthSafe
            if ($out.Length -lt ($w - 1)) {
                $out = $out + (' ' * (($w - 1) - $out.Length))
            } else {
                $out = $out.Substring(0, [Math]::Max(0, $w - 1))
            }
        }
        [Console]::Write($out)
    } catch {
    } finally {
        try {
            [Console]::ForegroundColor = $oldFg
            [Console]::BackgroundColor = $oldBg
        } catch { }
    }
}

function Clear-TuiScreen {
    param(
        [bool]$UseVt
    )
    try {
        if ($UseVt) {
            $esc = [char]27
            [Console]::Write("${esc}[H${esc}[2J")
        } else {
            [Console]::Clear()
        }
    } catch {
        try { Clear-Host } catch { }
    }
}

function Start-TuiFrame {
    param(
        [bool]$UseVt
    )
    $state = [pscustomobject]@{
        UseVt = $UseVt
        CursorWasVisible = $true
        AltBuffer = $false
        RenderTop = 0
    }

    try {
        $state.CursorWasVisible = [Console]::CursorVisible
        [Console]::CursorVisible = $false
    } catch { }

    # NOTE: alternate screen buffer disabled (caused literal escape text in some hosts)

    try {
        [Console]::SetCursorPosition(0, 0)
        $state.RenderTop = 0
    } catch {
        $state.RenderTop = 0
    }

    return $state
}

function Stop-TuiFrame {
    param(
        $State
    )

    if ($null -eq $State) { return }
    try {
        [Console]::CursorVisible = [bool]$State.CursorWasVisible
    } catch { }
}

function Write-TuiFrame {
    param(
        [string]$Frame,
        $State
    )

    try {
        [Console]::SetCursorPosition(0, $State.RenderTop)
        if ($State.UseVt) {
            # Home + clear-to-end to prevent leftovers
            $esc = [char]27
            Write-Host ("${esc}[H") -NoNewline
            Write-Host $Frame -NoNewline
            Write-Host ("${esc}[J") -NoNewline
        } else {
            Write-Host $Frame -NoNewline
        }
    } catch {
        Clear-Host
        Write-Host $Frame
    }
}

function Show-Menu {
    param(
        [string]$Title = "",
        [string]$Header = "",
        [string[]]$Options,
        [int]$Current = 0,
        [bool]$AllowCancel = $true,
        [bool]$EnableHorizontalNav = $false
    )

    if (-not $Options) { return -1 }

    $theme = Get-TuiTheme
    $tui = Start-TuiFrame -UseVt (Test-VtSupported)
    try {
        Clear-TuiScreen -UseVt $tui.UseVt
        $row = 0

        # Title
        $row++
        if ($Title) {
            Write-ConsoleAt -Left 0 -Top $row -Text $Title -ForegroundColor $theme.TitleFg -BackgroundColor ([Console]::BackgroundColor) -ClearToEnd
            $row += 2
        }

        # Header
        if ($Header) {
            Write-ConsoleAt -Left 0 -Top $row -Text $Header -ForegroundColor $theme.HeaderFg -BackgroundColor ([Console]::BackgroundColor) -ClearToEnd
            $row += 2
        }

        $optionsTop = $row

        function Render-MenuLine {
            param(
                [int]$Index,
                [bool]$Selected
            )
            $prefix = if ($Selected) { " > " } else { "   " }
            $text = $prefix + [string]$Options[$Index]
            if ($Selected) {
                Write-ConsoleAt -Left 0 -Top ($optionsTop + $Index) -Text $text -ForegroundColor $theme.SelectedFg -BackgroundColor $theme.SelectedBg -ClearToEnd
            } else {
                Write-ConsoleAt -Left 0 -Top ($optionsTop + $Index) -Text $text -ForegroundColor $theme.OptionFg -BackgroundColor ([Console]::BackgroundColor) -ClearToEnd
            }
        }

        for ($i = 0; $i -lt $Options.Count; $i++) {
            Render-MenuLine -Index $i -Selected ($i -eq $Current)
        }

        while ($true) {
            $keyInfo = [Console]::ReadKey($true)

            $prev = $Current
            $moved = $false

            switch ($keyInfo.Key) {
                'UpArrow'    { if ($Current -gt 0) { $Current--; $moved = $true } }
                'DownArrow'  { if ($Current -lt ($Options.Count - 1)) { $Current++; $moved = $true } }
                'LeftArrow'  { if ($EnableHorizontalNav) { return -2 } }
                'RightArrow' { if ($EnableHorizontalNav) { return -3 } }
                'Enter'      { return $Current }
                'Escape'     { if ($AllowCancel) { return -1 } }
                default {
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

            if ($moved -and $prev -ne $Current) {
                Render-MenuLine -Index $prev -Selected $false
                Render-MenuLine -Index $Current -Selected $true
            }
        }
    } finally {
        Stop-TuiFrame -State $tui
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
    $offset = 0

    $cachedFilter = $null
    $cachedMatches = @()
    $cachedUnfiltered = @()
    $lastOptionsHash = 0
    $lastPinnedHash = 0

    $theme = Get-TuiTheme
    $tui = Start-TuiFrame -UseVt (Test-VtSupported)
    $needsFullRender = $true
    $cachedToShow = @()
    $optionsTop = 0
    $lastRenderedCount = 0

    function Render-FilterLine {
        param(
            [int]$Index,
            [bool]$Selected
        )
        if ($Index -lt 0 -or $Index -ge $cachedToShow.Count) { return }
        $lineText = " > $($cachedToShow[$Index])"
        if (-not $Selected) { $lineText = "   $($cachedToShow[$Index])" }

        if ($Selected) {
            Write-ConsoleAt -Left 0 -Top ($optionsTop + $Index) -Text $lineText -ForegroundColor $theme.SelectedFg -BackgroundColor $theme.SelectedBg -ClearToEnd
        } else {
            Write-ConsoleAt -Left 0 -Top ($optionsTop + $Index) -Text $lineText -ForegroundColor $theme.OptionFg -BackgroundColor ([Console]::BackgroundColor) -ClearToEnd
        }
    }

    try {
    while ($true) {
        # Cache recomputation only when filter/options/pinned change
        $optionsHash = 0
        $pinnedHash = 0
        try { $optionsHash = ($Options -join "`n").GetHashCode() } catch { $optionsHash = 0 }
        try { $pinnedHash = ($PinnedOptions -join "`n").GetHashCode() } catch { $pinnedHash = 0 }

        $mustRecompute = $needsFullRender -or ($cachedFilter -ne $filter) -or ($optionsHash -ne $lastOptionsHash) -or ($pinnedHash -ne $lastPinnedHash)
        if ($mustRecompute) {
            $filterTokens = @()
            if (-not [string]::IsNullOrWhiteSpace($filter)) {
                $filterTokens = $filter.Split(@(' ',"\t"), [System.StringSplitOptions]::RemoveEmptyEntries)
            }

            $cachedUnfiltered = @($Options | Where-Object { $PinnedOptions -notcontains $_ })

            $baseMatches = if ($filterTokens.Count -eq 0) {
                $cachedUnfiltered
            } else {
                $cachedUnfiltered | Where-Object {
                    $candidate = $_
                    $ok = $true
                    foreach ($t in $filterTokens) {
                        if ($candidate -notlike "*${t}*") { $ok = $false; break }
                    }
                    $ok
                }
            }

            $cachedMatches = @($baseMatches)
            $cachedFilter = $filter
            $lastOptionsHash = $optionsHash
            $lastPinnedHash = $pinnedHash
            $offset = 0
            $current = 0
        }

        # Paginazione: pinned sempre visibili; il resto è paginato.
        $pinned = @($PinnedOptions)
        $rest = @($cachedMatches)

        $pageCapacity = [Math]::Max(1, ($MaxVisible - $pinned.Count))
        $restTotal = $rest.Count
        $maxOffset = if ($restTotal -le $pageCapacity) { 0 } else { [Math]::Max(0, $restTotal - $pageCapacity) }
        if ($offset -gt $maxOffset) { $offset = $maxOffset }
        if ($offset -lt 0) { $offset = 0 }

        $restPage = @()
        if ($restTotal -gt 0) {
            $restPage = @($rest | Select-Object -Skip $offset -First $pageCapacity)
        }

        $matches = @($pinned) + @($restPage)

        if ($matches.Count -eq 0) {
            $current = 0
        } else {
            if ($current -lt 0) { $current = 0 }
            if ($current -ge $matches.Count) { $current = [Math]::Max(0, $matches.Count - 1) }
        }

        if ($needsFullRender) {
            Clear-TuiScreen -UseVt $tui.UseVt

            $row = 0
            $row++
            if ($Title) {
                Write-ConsoleAt -Left 0 -Top $row -Text $Title -ForegroundColor $theme.TitleFg -BackgroundColor ([Console]::BackgroundColor) -ClearToEnd
                $row += 2
            }
            if ($Header) {
                Write-ConsoleAt -Left 0 -Top $row -Text $Header -ForegroundColor $theme.HeaderFg -BackgroundColor ([Console]::BackgroundColor) -ClearToEnd
                $row += 2
            }

            $filterLine = if ([string]::IsNullOrWhiteSpace($filter)) { $Placeholder } else { $filter }
            Write-ConsoleAt -Left 0 -Top $row -Text ("Filter: {0}" -f $filterLine) -ForegroundColor $theme.InputFg -BackgroundColor ([Console]::BackgroundColor) -ClearToEnd
            $row++
            $totalLabel = ($pinned.Count + $restTotal)
            $pageLabel = ""
            if ($restTotal -gt $pageCapacity) {
                $pageIdx = [Math]::Floor($offset / $pageCapacity) + 1
                $pageCount = [Math]::Ceiling($restTotal / [double]$pageCapacity)
                $pageLabel = "  |  Page ${pageIdx}/${pageCount} (use )"
            }
            Write-ConsoleAt -Left 0 -Top $row -Text ("Matches: {0}{1}" -f $totalLabel, $pageLabel) -ForegroundColor $theme.MutedFg -BackgroundColor ([Console]::BackgroundColor) -ClearToEnd
            $row += 2

            $cachedToShow = @($matches | Select-Object -First $MaxVisible)
            $optionsTop = $row
            $lastRenderedCount = $cachedToShow.Count
            for ($i = 0; $i -lt $cachedToShow.Count; $i++) {
                Render-FilterLine -Index $i -Selected ($i -eq $current)
            }

            if ($matches.Count -gt $MaxVisible) {
                Write-ConsoleAt -Left 0 -Top ($optionsTop + $MaxVisible + 1) -Text ("... showing first {0} results" -f $MaxVisible) -ForegroundColor $theme.MutedFg -BackgroundColor ([Console]::BackgroundColor) -ClearToEnd
            }

            $needsFullRender = $false
        }

        $keyInfo = [Console]::ReadKey($true)
        switch ($keyInfo.Key) {
            'UpArrow'   {
                if ($current -gt 0) {
                    $prev = $current
                    $current--
                    Render-FilterLine -Index $prev -Selected $false
                    Render-FilterLine -Index $current -Selected $true
                }
            }
            'DownArrow' {
                $maxIdx = [Math]::Min($MaxVisible, $matches.Count) - 1
                if ($current -lt $maxIdx) {
                    $prev = $current
                    $current++
                    Render-FilterLine -Index $prev -Selected $false
                    Render-FilterLine -Index $current -Selected $true
                }
            }
            'LeftArrow' {
                if ($restTotal -gt $pageCapacity -and $offset -gt 0) {
                    $offset = [Math]::Max(0, $offset - $pageCapacity)
                    $needsFullRender = $true
                }
            }
            'RightArrow' {
                if ($restTotal -gt $pageCapacity -and ($offset + $pageCapacity) -lt $restTotal) {
                    $offset = [Math]::Min($maxOffset, ($offset + $pageCapacity))
                    $needsFullRender = $true
                }
            }
            'Enter' {
                if ($matches.Count -eq 0) {
                    if ($EnterReturnsFilterWhenNoMatch -and (-not [string]::IsNullOrWhiteSpace($filter))) {
                        return $filter
                    }
                    continue
                }

                return $cachedToShow[$current]
            }
            'Escape' { if ($AllowCancel) { return $null } }
            'Backspace' {
                if ($filter.Length -gt 0) {
                    $filter = $filter.Substring(0, $filter.Length - 1)
                    $current = 0
                    $offset = 0
                    $needsFullRender = $true
                }
            }
            default {
                $c = $keyInfo.KeyChar
                if ($c -and (-not [char]::IsControl($c))) {
                    $filter += $c
                    $current = 0
                    $offset = 0
                    $needsFullRender = $true
                }
            }
        }
    }
    } finally {
        Stop-TuiFrame -State $tui
    }
}

