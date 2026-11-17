# One-shot GitHub device-flow login: retries through the flaky github.com link,
# then stores the credential in gh. ASCII-only (PS 5.1 reads .ps1 as ANSI without BOM).
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$ghPath  = 'C:\Program Files\GitHub CLI\gh.exe'
$logFile = Join-Path $env:TEMP 'gh_login_all.log'
function Log($m) {
    $line = "[{0}] {1}" -f (Get-Date).ToString('HH:mm:ss'), $m
    Add-Content -Path $logFile -Value $line -Encoding UTF8
}

$clientId = '178c6fc778ccc68e1d6a'
$body = @{ client_id = $clientId; scope = 'repo read:org gist' }

# --- phase 1: get a device code, retrying until the network cooperates ---
$res = $null
for ($i = 1; $i -le 60 -and -not $res; $i++) {
    try {
        $res = Invoke-RestMethod -Method Post `
            -Uri 'https://github.com/login/device/code' `
            -Headers @{ 'Accept' = 'application/json' } `
            -Body $body -TimeoutSec 15
        Log "device code obtained on attempt $i"
    } catch {
        Log "attempt $i failed: $($_.Exception.Message)"
        Start-Sleep -Seconds 3
    }
}
if (-not $res) { Log 'FATAL: no device code'; exit 1 }

try { Set-Clipboard -Value $res.user_code } catch {}
try { Start-Process $res.verification_uri } catch {}
Log ("USER CODE: {0}  (https://github.com/login/device, expires {1} min)" -f $res.user_code, [math]::Round($res.expires_in / 60, 0))

# --- phase 2: poll for the token ---
$interval = [int]$res.interval
if ($interval -lt 5) { $interval = 5 }
$expiresAt = (Get-Date).AddSeconds($res.expires_in)
$token = $null

while ((Get-Date) -lt $expiresAt -and -not $token) {
    Start-Sleep -Seconds $interval
    try {
        $r = Invoke-RestMethod -Method Post `
            -Uri 'https://github.com/login/oauth/access_token' `
            -Headers @{ 'Accept' = 'application/json' } `
            -Body @{
                client_id   = $clientId
                device_code = $res.device_code
                grant_type  = 'urn:ietf:params:oauth:grant-type:device_code'
            } -TimeoutSec 15
    } catch {
        Log "poll transient: $($_.Exception.Message)"
        continue
    }
    if ($r.access_token) { $token = $r.access_token; Log 'authorized: token received'; break }
    switch ($r.error) {
        'authorization_pending' { Log 'pending' }
        'slow_down'             { $interval += 5; Log "slow_down -> $interval" }
        'expired_token'         { Log 'code expired'; exit 2 }
        'access_denied'         { Log 'denied by user'; exit 3 }
        default                 { Log "unexpected: $($r.error)" }
    }
}
if (-not $token) { Log 'FATAL: no token before expiry'; exit 1 }

# --- phase 3: store credentials ---
$stored = $false
try {
    $out = $token | & $ghPath auth login --hostname github.com --git-protocol https --with-token 2>&1
    $out | ForEach-Object { Log "gh: $_" }
    if ($LASTEXITCODE -eq 0) { $stored = $true; Log 'gh auth login OK' }
} catch {
    Log "gh auth login threw: $($_.Exception.Message)"
}

if (-not $stored) {
    try {
        $user = (Invoke-RestMethod -Uri 'https://api.github.com/user' -Headers @{
            Authorization = "Bearer $token"; 'User-Agent' = 'wispterm-setup'
        } -TimeoutSec 20).login
        $cfgDir = Join-Path $env:APPDATA 'GitHub CLI'
        if (-not (Test-Path $cfgDir)) { New-Item -ItemType Directory -Path $cfgDir -Force | Out-Null }
        $hosts = @"
github.com:
    user: $user
    oauth_token: $token
    git_protocol: https
"@
        Set-Content -Path (Join-Path $cfgDir 'hosts.yml') -Value $hosts -Encoding UTF8
        Log "wrote hosts.yml manually as $user"
    } catch {
        Log "fallback store failed: $($_.Exception.Message)"
    }
}

try { & $ghPath auth setup-git 2>&1 | ForEach-Object { Log "setup-git: $_" } } catch {}
Log 'DONE'
