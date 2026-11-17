# publish.ps1 - one-click publish: syntax check, commit, push. GitHub Pages rebuilds in about a minute.
# Usage: double-click publish.cmd in the project folder, or:
#   powershell -ExecutionPolicy Bypass -File tools\publish.ps1 -Message "add news item"

param(
    [string]$Message = "Update site content",
    [switch]$NoPause
)

$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$site = "https://luobinjie687.github.io/"

# --- locate git (not always on PATH on this machine) ---
$git = (Get-Command git -ErrorAction SilentlyContinue).Source
if (-not $git) { $git = "$env:ProgramFiles\Git\cmd\git.exe" }
if (-not (Test-Path $git)) {
    Write-Host "git not found. Install it from https://git-scm.com/download/win" -ForegroundColor Red
    if (-not $NoPause) { Read-Host "Press Enter to close" }
    exit 1
}

# --- step 1: syntax check ---
Write-Host "[1/3] checking JavaScript syntax ..."
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "check-site.ps1") | Out-Host
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Aborted: fix the syntax error in data\site.js first." -ForegroundColor Red
    if (-not $NoPause) { Read-Host "Press Enter to close" }
    exit 1
}

# --- step 2: commit ---
Write-Host "[2/3] committing ..."
& $git add -A
$pending = (& $git status --porcelain) | Out-String
if ([string]::IsNullOrWhiteSpace($pending)) {
    Write-Host "Nothing changed since the last publish. Nothing to do." -ForegroundColor Yellow
    if (-not $NoPause) { Read-Host "Press Enter to close" }
    exit 0
}
& $git commit -m $Message
if ($LASTEXITCODE -ne 0) {
    Write-Host "Commit failed." -ForegroundColor Red
    if (-not $NoPause) { Read-Host "Press Enter to close" }
    exit 1
}

# --- step 3: push with retries (github.com is flaky on some networks) ---
Write-Host "[3/3] pushing to GitHub ..."
$ok = $false
for ($i = 1; $i -le 8; $i++) {
    Write-Host "  attempt $i ..."
    & $git push origin main 2>&1 | Out-Host
    if ($LASTEXITCODE -eq 0) { $ok = $true; break }
    Start-Sleep -Seconds 4
}

Write-Host ""
if ($ok) {
    Write-Host "Published. Your site rebuilds in about a minute:" -ForegroundColor Green
    Write-Host "  $site" -ForegroundColor Green
    Write-Host "If you still see the old version, wait 60 seconds and press Ctrl+F5."
} else {
    Write-Host "Push failed 8 times - the network could not reach github.com." -ForegroundColor Red
    Write-Host "Your edit is saved locally and the commit is safe. Run publish.cmd again later."
}
if (-not $NoPause) { Read-Host "Press Enter to close" }
