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
$errLog = Join-Path $env:TEMP "homepage-git-stderr.log"

function Wait-Exit {
    if (-not $NoPause) { Read-Host "Press Enter to close" }
}

# git writes its progress lines to stderr, which PowerShell would render as red errors.
# Run it with stderr captured to a file, then print those lines in grey.
function Invoke-Git {
    param([string[]]$GitArgs)
    if (Test-Path $errLog) { Remove-Item $errLog -Force -ErrorAction SilentlyContinue }
    & $git @GitArgs 2> $errLog | Out-Host
    $code = $LASTEXITCODE
    if (Test-Path $errLog) {
        Get-Content $errLog -ErrorAction SilentlyContinue | Where-Object { $_.Trim() } | ForEach-Object {
            Write-Host "    $_" -ForegroundColor DarkGray
        }
    }
    return $code
}

# --- locate git (not on PATH on this machine by default) ---
$git = (Get-Command git -ErrorAction SilentlyContinue).Source
if (-not $git) { $git = "$env:ProgramFiles\Git\cmd\git.exe" }
if (-not (Test-Path $git)) {
    Write-Host "git not found. Install it from https://git-scm.com/download/win" -ForegroundColor Red
    Wait-Exit
    exit 1
}

# --- step 1: syntax check ---
Write-Host "[1/3] checking JavaScript syntax ..."
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "check-site.ps1") | Out-Host
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Aborted: fix the syntax error in data\site.js first. Nothing was published." -ForegroundColor Red
    Wait-Exit
    exit 1
}

# --- step 2: commit ---
Write-Host "[2/3] committing ..."
Invoke-Git @('add', '-A') | Out-Null
$pending = (& $git status --porcelain 2>$null) | Out-String
if ([string]::IsNullOrWhiteSpace($pending)) {
    Write-Host "Nothing changed since the last publish. Nothing to do." -ForegroundColor Yellow
    Wait-Exit
    exit 0
}
$code = Invoke-Git @('commit', '-m', $Message)
if ($code -ne 0) {
    Write-Host "Commit failed." -ForegroundColor Red
    Wait-Exit
    exit 1
}

# --- step 3: push with retries (github.com is flaky on some networks) ---
Write-Host "[3/3] pushing to GitHub ..."
$ok = $false
for ($i = 1; $i -le 8; $i++) {
    Write-Host "  attempt $i ..."
    $code = Invoke-Git @('push', 'origin', 'main')
    if ($code -eq 0) { $ok = $true; break }
    Start-Sleep -Seconds 4
}

Write-Host ""
if ($ok) {
    Write-Host "Published. Your site rebuilds in about a minute:" -ForegroundColor Green
    Write-Host "  $site" -ForegroundColor Green
    Write-Host "Still seeing the old version? Wait 60s, then press Ctrl+F5 in the browser."
} else {
    Write-Host "Push failed 8 times - the network could not reach github.com." -ForegroundColor Red
    Write-Host "Your edit is saved locally and the commit is safe. Run publish.cmd again later."
}
Wait-Exit

