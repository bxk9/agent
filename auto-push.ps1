# auto-push.ps1
# Gradually git add, commit, and push one untracked file at a time
# with a random 3-5 second interval between each push.

param(
    [string]$Branch = "main"
)

$ErrorActionPreference = "Stop"

function Get-UntrackedFiles {
    $raw = git ls-files --others --exclude-standard 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Failed to list untracked files." -ForegroundColor Red
        return @()
    }
    if (-not $raw) {
        return @()
    }
    # Ensure we always return an array
    $files = @($raw | Where-Object { $_ -match '^[^\s]' -and $_.Trim().Length -gt 0 })
    return $files
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

    # Random sleep between 3 and 5 seconds
    $delay = Get-Random -Minimum 3 -Maximum 6
    Write-Host "[WAIT] Sleeping $delay seconds ..." -ForegroundColor DarkGray
    Start-Sleep -Seconds $delay
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host " Finished. Total files pushed: $totalPushed" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
