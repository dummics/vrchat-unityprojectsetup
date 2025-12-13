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

    $progressId = 1
    try {
        if ($Process -and $Process.Id -gt 0) { $progressId = 1000 + [int]$Process.Id }
    } catch { $progressId = 1 }

    $useWriteProgress = $true
    if ($env:VRCSETUP_PROGRESS_PLAIN -eq '1') { $useWriteProgress = $false }
    try {
        if ($null -eq $Host -or $null -eq $Host.UI -or $null -eq $Host.UI.RawUI) { $useWriteProgress = $false }
    } catch { $useWriteProgress = $false }

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

        $maxLogLen = 120
        if (-not $useWriteProgress) {
            $winWidth = 120
            try { $winWidth = [Console]::WindowWidth } catch { $winWidth = 120 }
            $maxLogLen = [Math]::Max(40, $winWidth - 50)
        }

        # Sanitize control chars/newlines from Unity log tail (prevents cursor jumps / corruption)
        $cleanLog = [string]$lastLog
        if (-not [string]::IsNullOrEmpty($cleanLog)) {
            $cleanLog = $cleanLog -replace "`r|`n|`t", ' '
            $cleanLog = $cleanLog -replace "[\x00-\x1F\x7F]", ''
        }

        $displayLog = if ($cleanLog.Length -gt $maxLogLen) { $cleanLog.Substring(0, $maxLogLen) + "..." } else { $cleanLog }

        if ($useWriteProgress) {
            $status = "Time ${elapsedStr} | CPU: ${cpuPercent}% | RAM: ${memoryMB}MB"
            try {
                Write-Progress -Id $progressId -Activity $Prefix -Status $status -CurrentOperation $displayLog
            } catch {
                # If the host can't render progress, fall back to plain output.
                $useWriteProgress = $false
            }
        }

        if (-not $useWriteProgress) {
            $statusLine = "${Prefix} ${elapsedStr} | CPU: ${cpuPercent}% | RAM: ${memoryMB}MB | ${displayLog}"
            Write-Host $statusLine
        }
    }

    # Final line
    $elapsed = (Get-Date) - $startTime
    $elapsedStr = "{0:mm}:{0:ss}" -f $elapsed
    try {
        if ($useWriteProgress) { Write-Progress -Id $progressId -Activity $Prefix -Completed }
    } catch { }

    $finalMsg = ("${Prefix} Completed! Time: {0}" -f $elapsedStr)
    Write-Host $finalMsg -ForegroundColor Green
    return @{ Elapsed = $elapsedStr; Cpu = $cpuPercent; MemoryMB = $memoryMB; ExitCode = $Process.ExitCode }
}

