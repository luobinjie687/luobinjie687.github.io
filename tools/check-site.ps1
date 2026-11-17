# check-site.ps1 - syntax check for the site's JavaScript before publishing.
# Usage: right-click -> Run with PowerShell, or: powershell -ExecutionPolicy Bypass -File tools\check-site.ps1
# Catches the most common editing mistake: a missing comma or quote in data\site.js.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$node = (Get-Command node -ErrorAction SilentlyContinue).Source
if (-not $node) {
    $candidates = @(
        "$env:USERPROFILE\Documents\Codex\.bear-research\bin\node.cmd",
        "$env:ProgramFiles\nodejs\node.exe",
        "$env:LOCALAPPDATA\Programs\nodejs\node.exe"
    )
    foreach ($c in $candidates) { if (Test-Path $c) { $node = $c; break } }
}

if (-not $node) {
    Write-Host "node not found - cannot run the syntax check." -ForegroundColor Yellow
    Write-Host "If the page goes blank after editing, you probably missed a comma or a quote in data\site.js."
    exit 0
}

$files = @('data/site.js', 'assets/main.js')
$bad = $false
foreach ($f in $files) {
    if (-not (Test-Path $f)) { Write-Host "MISSING: $f" -ForegroundColor Red; $bad = $true; continue }
    $out = & $node --check $f 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        $bad = $true
        Write-Host "SYNTAX ERROR in $f" -ForegroundColor Red
        Write-Host $out.Trim()
    } else {
        Write-Host "OK  $f" -ForegroundColor Green
    }
}

if ($bad) {
    Write-Host ""
    Write-Host "Fix the error above, then run this check again." -ForegroundColor Red
    Write-Host "Tip: restore your backup copy of data\site.js if it gets confusing."
    exit 1
}

Write-Host ""
Write-Host "All good. Open index.html to preview, or run publish.cmd to put it online." -ForegroundColor Green
exit 0
