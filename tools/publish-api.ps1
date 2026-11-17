# publish-api.ps1 - publish the current site content to GitHub through the REST API
# (api.github.com) instead of a git push over https://github.com.
#
# Why: on this machine github.com:443 is intermittently unreachable, which breaks
# `git push`, while api.github.com stays reachable. This script builds one commit
# from the working tree with the Git Data API, so no transfer to github.com happens.
#
# Called automatically by publish.ps1 when git push fails.

param(
    [string]$Message = "Update site content",
    [string]$Repo = "luobinjie687/luobinjie687.github.io",
    [string]$Branch = "main",
    [switch]$NoPause,
    [switch]$DryRun
)

$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Wait-Exit { if (-not $NoPause) { Read-Host "Press Enter to close" } }

function Find-Gh {
    $c = (Get-Command gh -ErrorAction SilentlyContinue).Source
    if ($c) { return $c }
    foreach ($p in @("$env:ProgramFiles\GitHub CLI\gh.exe", "$env:LOCALAPPDATA\Programs\GitHub CLI\gh.exe")) {
        if (Test-Path $p) { return $p }
    }
    return $null
}

function Find-Git {
    $c = (Get-Command git -ErrorAction SilentlyContinue).Source
    if ($c) { return $c }
    foreach ($p in @("$env:ProgramFiles\Git\cmd\git.exe", "${env:ProgramFiles(x86)}\Git\cmd\git.exe")) {
        if (Test-Path $p) { return $p }
    }
    return $null
}

function Invoke-GhApi {
    param([string]$Method, [string]$Path, [string]$JsonFile)
    $a = @('api', '-X', $Method, $Path)
    if ($JsonFile) { $a += @('--input', $JsonFile) }
    $out = & $gh @a 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "gh api $Method $Path failed: $($out.Trim())" }
    return ($out | ConvertFrom-Json)
}

$gh = Find-Gh
if (-not $gh) { Write-Host "gh not found." -ForegroundColor Red; Wait-Exit; exit 1 }
$git = Find-Git
if (-not $git) { Write-Host "git not found." -ForegroundColor Red; Wait-Exit; exit 1 }

$tmpDir = Join-Path $env:TEMP ("homepage-api-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

try {
    # --- 0. sanity: repo reachable through the API ---
    Write-Host "[api 1/5] reading current commit on $Repo@$Branch ..."
    $ref = Invoke-GhApi -Method GET -Path "repos/$Repo/git/ref/heads/$Branch"
    $parentSha = $ref.object.sha
    Write-Host "    parent: $parentSha"

    # --- 1. upload every tracked file as a blob ---
    $files = & $git ls-files
    if (-not $files) { Write-Host "No tracked files." -ForegroundColor Red; Wait-Exit; exit 1 }
    Write-Host "[api 2/5] uploading $($files.Count) files as blobs ..."
    $entries = @()
    $n = 0
    foreach ($f in $files) {
        $n++
        $full = Join-Path $root ($f -replace '/', '\')
        if (-not (Test-Path $full)) { Write-Host "    skip missing: $f" -ForegroundColor Yellow; continue }
        $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($full))
        $body = @{ content = $b64; encoding = 'base64' } | ConvertTo-Json -Compress
        $bf = Join-Path $tmpDir "blob.json"
        [IO.File]::WriteAllText($bf, $body, [Text.UTF8Encoding]::new($false))
        $blob = Invoke-GhApi -Method POST -Path "repos/$Repo/git/blobs" -JsonFile $bf
        $entries += @{ path = $f; mode = '100644'; type = 'blob'; sha = $blob.sha }
        Write-Host ("    ({0}/{1}) {2}" -f $n, $files.Count, $f)
    }

    # --- 2. create the tree ---
    Write-Host "[api 3/5] creating tree ..."
    $treeBody = @{ tree = $entries } | ConvertTo-Json -Depth 6 -Compress
    $tf = Join-Path $tmpDir "tree.json"
    [IO.File]::WriteAllText($tf, $treeBody, [Text.UTF8Encoding]::new($false))
    $tree = Invoke-GhApi -Method POST -Path "repos/$Repo/git/trees" -JsonFile $tf
    Write-Host "    tree: $($tree.sha)"

    # --- 3. create the commit ---
    Write-Host "[api 4/5] creating commit ..."
    $commitBody = @{ message = $Message; tree = $tree.sha; parents = @($parentSha) } | ConvertTo-Json -Compress
    $cf = Join-Path $tmpDir "commit.json"
    [IO.File]::WriteAllText($cf, $commitBody, [Text.UTF8Encoding]::new($false))
    $commit = Invoke-GhApi -Method POST -Path "repos/$Repo/git/commits" -JsonFile $cf
    Write-Host "    commit: $($commit.sha)"

    # --- 4. fast-forward the branch ---
    if ($DryRun) {
        Write-Host "[api 5/5] DRY RUN - skipping the branch update"
        Write-Host "Dry run OK: blobs, tree and commit all accepted." -ForegroundColor Green
        exit 0
    }
    Write-Host "[api 5/5] updating $Branch ..."
    $refBody = @{ sha = $commit.sha; force = $false } | ConvertTo-Json -Compress
    $rf = Join-Path $tmpDir "ref.json"
    [IO.File]::WriteAllText($rf, $refBody, [Text.UTF8Encoding]::new($false))
    $null = Invoke-GhApi -Method PATCH -Path "repos/$Repo/git/refs/heads/$Branch" -JsonFile $rf

    # --- 5. leave a marker so the next normal publish can resync local history ---
    # The commit object we just created does not exist locally (we cannot fetch it while
    # github.com is unreachable). publish.ps1 uses this marker to ``git reset --hard`` onto
    # origin/main once the network is back. Content is identical, so nothing is lost.
    $marker = Join-Path $root ".git\api-publish-pending"
    [IO.File]::WriteAllText($marker, $commit.sha, [Text.UTF8Encoding]::new($false))

    Write-Host ""
    Write-Host "Published through the API (no github.com transfer needed)." -ForegroundColor Green
    Write-Host "  https://luobinjie687.github.io/   (rebuilds in about a minute)" -ForegroundColor Green
    exit 0
}
catch {
    Write-Host ""
    Write-Host "API publish failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Your files are saved locally. Try again later, or run publish.cmd." -ForegroundColor Yellow
    Wait-Exit
    exit 1
}
finally {
    Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
}
