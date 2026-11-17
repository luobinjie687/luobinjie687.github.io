# publish.ps1 - one-click publish: syntax check, commit, push. GitHub Pages rebuilds in about a minute.
# Usage: double-click publish.cmd in the project folder, or:
#   powershell -ExecutionPolicy Bypass -File tools\publish.ps1 -Message "add news item"
#
# Two transports:
#   1. git push over https://github.com  (normal)
#   2. REST API via api.github.com        (automatic fallback when github.com:443 is unreachable)

param(
    [string]$Message = "Update site content",
    [switch]$NoPause
)

$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$site    = "https://luobinjie687.github.io/"
$errLog  = Join-Path $env:TEMP "homepage-git-stderr.log"
$marker  = Join-Path $root ".git\api-publish-pending"

function Wait-Exit { if (-not $NoPause) { Read-Host "Press Enter to close" } }

# git writes progress to stderr, which PowerShell would render as scary red errors.
# Run git through a .NET process object instead, so stderr is plain text we can print in grey.
function Invoke-Git {
    param([string[]]$GitArgs)

    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = $git
    $psi.Arguments = ($GitArgs | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' '
    $psi.WorkingDirectory = $root
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [Text.UTF8Encoding]::new($false)
    $psi.StandardErrorEncoding = [Text.UTF8Encoding]::new($false)

    $p = [Diagnostics.Process]::Start($psi)
    $out = $p.StandardOutput.ReadToEnd()
    $err = $p.StandardError.ReadToEnd()
    $p.WaitForExit()

    if ($out.Trim()) { Write-Host $out.TrimEnd() }
    if ($err.Trim()) {
        foreach ($line in ($err -split "`r?`n")) {
            if ($line.Trim()) { Write-Host "    $line" -ForegroundColor DarkGray }
        }
    }
    return $p.ExitCode
}

function Test-GithubHttps {
    param([int]$TimeoutMs = 6000)
    $c = New-Object Net.Sockets.TcpClient
    try { return $c.ConnectAsync('github.com', 443).Wait($TimeoutMs) }
    catch { return $false }
    finally { $c.Close() }
}

# --- locate git (not on PATH on this machine by default) ---
$git = (Get-Command git -ErrorAction SilentlyContinue).Source
if (-not $git) { $git = "$env:ProgramFiles\Git\cmd\git.exe" }
if (-not (Test-Path $git)) {
    Write-Host "git not found. Install it from https://git-scm.com/download/win" -ForegroundColor Red
    Wait-Exit
    exit 1
}

# --- step 0: if a previous publish went through the API, realign local history ---
if (Test-Path $marker) {
    Write-Host "[0/4] previous publish used the API - realigning local git ..."
    if (Test-GithubHttps) {
        # IMPORTANT: reset --hard throws away uncommitted edits, so never run it on a dirty tree.
        # Stash the working tree first, realign, then put the edits back on top.
        $dirty = ((& $git status --porcelain 2>$null) | Out-String).Trim()
        $stashed = $false
        if ($dirty) {
            Write-Host "    your edits are not committed yet - saving them first ..."
            $code = Invoke-Git @('stash', 'push', '-u', '-m', 'publish-autosave')
            if ($code -ne 0) {
                Write-Host "    could not save your edits, stopping before anything is touched." -ForegroundColor Red
                Wait-Exit
                exit 1
            }
            $stashed = $true
        }

        $code = Invoke-Git @('fetch', 'origin', 'main')
        if ($code -eq 0) {
            Invoke-Git @('reset', '--hard', 'origin/main') | Out-Null
            Remove-Item $marker -Force -ErrorAction SilentlyContinue
            Write-Host "    local history matches GitHub again" -ForegroundColor Green

            if ($stashed) {
                Write-Host "    putting your edits back ..."
                $code = Invoke-Git @('stash', 'pop')
                if ($code -ne 0) {
                    Write-Host ""
                    Write-Host "Stopped: git could not re-apply your edits automatically (conflict)." -ForegroundColor Red
                    Write-Host "Your edits are NOT lost - they are kept in git stash. To recover:" -ForegroundColor Yellow
                    Write-Host "  git stash list" -ForegroundColor Yellow
                    Write-Host "  git stash pop" -ForegroundColor Yellow
                    Wait-Exit
                    exit 1
                }
                Write-Host "    edits restored" -ForegroundColor Green
            }
        } else {
            if ($stashed) { Invoke-Git @('stash', 'pop') | Out-Null }
            Write-Host "    fetch failed, will publish through the API again" -ForegroundColor Yellow
        }
    } else {
        Write-Host "    github.com unreachable, will publish through the API again" -ForegroundColor Yellow
    }
}

# --- step 1: syntax check ---
Write-Host "[1/4] checking JavaScript syntax ..."
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "check-site.ps1") | Out-Host
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Aborted: fix the syntax error in data\site.js first. Nothing was published." -ForegroundColor Red
    Wait-Exit
    exit 1
}

# --- step 2: commit ---
Write-Host "[2/4] committing ..."
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

# --- step 3: transport 1 - plain git push, if github.com is reachable ---
$ok = $false
if (Test-GithubHttps) {
    Write-Host "[3/4] pushing to GitHub ..."
    for ($i = 1; $i -le 3; $i++) {
        Write-Host "  attempt $i ..."
        $code = Invoke-Git @('push', 'origin', 'main')
        if ($code -eq 0) { $ok = $true; break }
        Start-Sleep -Seconds 3
    }
} else {
    Write-Host "[3/4] github.com:443 is unreachable from this network - switching to the API transport" -ForegroundColor Yellow
}

# --- step 4: transport 2 - REST API through api.github.com ---
if (-not $ok) {
    Write-Host "[4/4] publishing through the GitHub API ..."
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "publish-api.ps1") -Message $Message -NoPause | Out-Host
    $ok = ($LASTEXITCODE -eq 0)
}

Write-Host ""
if ($ok) {
    Write-Host "Published. Your site rebuilds in about a minute:" -ForegroundColor Green
    Write-Host "  $site" -ForegroundColor Green
    Write-Host "Still seeing the old version? Wait 60s, then press Ctrl+F5 in the browser."
} else {
    Write-Host "Publish failed on both transports." -ForegroundColor Red
    Write-Host "Your edit is saved locally and the commit is safe. Run publish.cmd again later."
}
Wait-Exit
