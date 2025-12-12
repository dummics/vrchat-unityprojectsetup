# Show a progress line for a background process, with CPU, RAM and log tail
function Show-ProcessProgress {
    param(
        [System.Diagnostics.Process]$Process,
        [string]$LogFile,
        [string]$Prefix = "[Process]",
        [int]$PollMs = 250
    )

    $startTime = Get-Date
    $lastLog = ""
    $lastStatsUpdate = Get-Date
    $cpuPercent = 0
    $memoryMB = 0
    $cursorTop = [Console]::CursorTop

    while (-not $Process.HasExited) {
        Start-Sleep -Milliseconds $PollMs
        $elapsed = (Get-Date) - $startTime
        $elapsedStr = "{0:mm}:{0:ss}" -f $elapsed

        if ((Get-Date) - $lastStatsUpdate -gt [TimeSpan]::FromSeconds(1)) {
            try {
                $unityProc = Get-Process -Id $Process.Id -ErrorAction SilentlyContinue
                if ($unityProc) {
                    $cpuPercent = [math]::Round($unityProc.CPU / $elapsed.TotalSeconds, 1)
                    $memoryMB = [math]::Round($unityProc.WorkingSet64 / 1MB, 0)
                }
            } catch { }
            $lastStatsUpdate = Get-Date
        }

        if (Test-Path $LogFile) {
            $newLog = Get-Content $LogFile -Tail 1 -ErrorAction SilentlyContinue
            if ($newLog -and $newLog -ne $lastLog) { $lastLog = $newLog }
        }

        $maxLogLen = [Math]::Max(40, [Console]::WindowWidth - 50)
        $displayLog = if ($lastLog.Length -gt $maxLogLen) { $lastLog.Substring(0, $maxLogLen) + "..." } else { $lastLog }

        $statusLine = "${Prefix} {0} | CPU: {1}% | RAM: {2}MB | {3}" -f $elapsedStr, $cpuPercent, $memoryMB, $displayLog
        $fullWidth = [Console]::WindowWidth - 1
        if ($statusLine.Length -gt $fullWidth) { $statusLine = $statusLine.Substring(0, $fullWidth) } else { $statusLine = $statusLine.PadRight($fullWidth) }
        try { [Console]::SetCursorPosition(0, $cursorTop); [Console]::Write($statusLine) } catch { $cursorTop = [Console]::CursorTop }
    }

    # Final line
    [Console]::SetCursorPosition(0, $cursorTop)
    $elapsed = (Get-Date) - $startTime
    $elapsedStr = "{0:mm}:{0:ss}" -f $elapsed
    $finalMsg = ("${Prefix} Completed! Time: {0}" -f $elapsedStr)
    Write-Host $finalMsg.PadRight([Console]::WindowWidth - 1) -ForegroundColor Green
    return @{ Elapsed = $elapsedStr; Cpu = $cpuPercent; MemoryMB = $memoryMB; ExitCode = $Process.ExitCode }
}

Export-ModuleMember -Function Show-ProcessProgress
