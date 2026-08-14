# auto-push.ps1
# Gradually git add, commit, and push one untracked file at a time
# with a random 3-5 second interval between each push.

param(
    [string]$Branch = "main"
)

$ErrorActionPreference = "Stop"

# Force UTF-8 so git outputs real characters, not octal escapes
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$env:LC_ALL = "C.UTF-8"

function Get-UntrackedFiles {
    # -z  : NUL-separated output, no quoting, no escaping
    # core.quotepath=false : extra safety to avoid octal escapes
    $rawBytes = git -c core.quotepath=false ls-files --others --exclude-standard -z 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Failed to list untracked files." -ForegroundColor Red
        return @()
    }
    if (-not $rawBytes) {
        return @()
    }

    # Join all output into one string, then split by NUL
    $joined = $rawBytes -join ""
    $files = $joined -split "`0" | Where-Object { $_.Trim().Length -gt 0 }

    return @($files)
}

function Push-OneFile {
    param([string]$FilePath)

    Write-Host "[ADD]    $FilePath" -ForegroundColor Cyan
    git add -- $FilePath
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR]  git add failed for: $FilePath" -ForegroundColor Red
        return $false
    }

    $msg = "Add document: $FilePath"
    Write-Host "[COMMIT] $msg" -ForegroundColor Yellow
    git commit -m $msg
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR]  git commit failed." -ForegroundColor Red
        return $false
    }

    Write-Host "[PUSH]   Pushing to origin/$Branch ..." -ForegroundColor Green
    git push origin $Branch
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR]  git push failed." -ForegroundColor Red
        return $false
    }

    return $true
}

# ---- Main Loop ----
Write-Host "========================================" -ForegroundColor Magenta
Write-Host " Auto-Push: one file per push" -ForegroundColor Magenta
Write-Host " Interval : random 3-5 seconds" -ForegroundColor Magenta
Write-Host " Branch   : $Branch" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""

$totalPushed = 0

while ($true) {
    $files = Get-UntrackedFiles

    if ($files.Count -eq 0) {
        Write-Host "[DONE] No more untracked files. All pushed." -ForegroundColor Green
        break
    }

    # Pick the first file from the list
    $target = $files[0]
    Write-Host ""
    Write-Host "[INFO] Found $($files.Count) untracked file(s). Next: $target" -ForegroundColor White

    $ok = Push-OneFile -FilePath $target
    if ($ok) {
        $totalPushed++
        Write-Host "[OK]   Pushed file #$totalPushed successfully." -ForegroundColor Green
    } else {
        Write-Host "[SKIP] Failed to push, skipping this file." -ForegroundColor Red
    }

    # Random sleep between 3.0 and 6.0 seconds (with decimals)
    $delay = Get-Random -Minimum 1.0 -Maximum 4.0
    $delayRounded = [math]::Round($delay, 1)
    Write-Host "[WAIT] Sleeping $delayRounded seconds ..." -ForegroundColor DarkGray
    Start-Sleep -Milliseconds ([int]($delay * 1000))
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host " Finished. Total files pushed: $totalPushed" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
