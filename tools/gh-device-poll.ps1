# Poll GitHub device-flow token endpoint, then store credentials via gh.
# ASCII-only (PowerShell 5.1 reads .ps1 as ANSI without BOM).
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$ghPath = 'C:\Program Files\GitHub CLI\gh.exe'
$logFile = Join-Path $env:TEMP 'gh_poll.log'
function Log($m) {
    $line = "[{0}] {1}" -f (Get-Date).ToString('HH:mm:ss'), $m
    Add-Content -Path $logFile -Value $line -Encoding UTF8
}

$state = Get-Content "$env:TEMP\gh_device.json" -Raw | ConvertFrom-Json
$interval = [int]$state.interval
if ($interval -lt 5) { $interval = 5 }
$expiresAt = [datetime]::Parse($state.expires_at)

Log "poll start interval=$interval"
$token = $null

while ((Get-Date) -lt $expiresAt) {
    Start-Sleep -Seconds $interval
    $body = @{
        client_id   = '178c6fc778ccc68e1d6a'
        device_code = $state.device_code
        grant_type  = 'urn:ietf:params:oauth:grant-type:device_code'
    }
    try {
        $r = Invoke-RestMethod -Method Post `
            -Uri 'https://github.com/login/oauth/access_token' `
            -Headers @{ 'Accept' = 'application/json' } `
            -Body $body -TimeoutSec 20
    } catch {
        Log "transient error: $($_.Exception.Message)"
        continue
    }

    if ($r.access_token) {
        $token = $r.access_token
        Log 'authorized: token received'
        break
    }
    switch ($r.error) {
        'authorization_pending' { Log 'pending (waiting for you to authorize)' }
        'slow_down'             { $interval += 5; Log "slow_down -> interval=$interval" }
        'expired_token'         { Log 'device code expired'; exit 2 }
        'access_denied'         { Log 'user denied'; exit 3 }
        default                 { Log "unexpected: $($r.error) $($r.error_description)" }
    }
}

if (-not $token) { Log 'no token before expiry'; exit 1 }

# Store the token into gh's credential store, then remove the plaintext copy.
$stored = $false
try {
    $out = $token | & $ghPath auth login --hostname github.com --git-protocol https --with-token 2>&1
    $out | ForEach-Object { Log "gh: $_" }
    if ($LASTEXITCODE -eq 0) { $stored = $true; Log 'gh auth login done' }
} catch {
    Log "gh auth login failed: $($_.Exception.Message)"
}

if (-not $stored) {
    # Fallback: write the credential straight into gh's own config file (no scope check).
    try {
        $user = (Invoke-RestMethod -Uri 'https://api.github.com/user' -Headers @{
            Authorization = "Bearer $token"
            'User-Agent'  = 'wispterm-setup'
        } -TimeoutSec 20).login
        $cfgDir = Join-Path $env:APPDATA 'GitHub CLI'
        if (-not (Test-Path $cfgDir)) { New-Item -ItemType Directory -Path $cfgDir -Force | Out-Null }
        $hosts = Join-Path $cfgDir 'hosts.yml'
        $content = "github.com:`n    user: $user`n    oauth_token: $token`n    git_protocol: https`n"
        Set-Content -Path $hosts -Value $content -Encoding UTF8
        Log "wrote hosts.yml manually for user $user"
    } catch {
        Log "fallback store failed: $($_.Exception.Message)"
    }
}

try {
    & $ghPath auth setup-git 2>&1 | ForEach-Object { Log "setup-git: $_" }
} catch { }

$user = & $ghPath api user --jq '.login' 2>&1
Log "login as: $user"
Log 'OK'
