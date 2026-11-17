# Start GitHub Device Flow: request a one-time code, open the authorization page.
# ASCII-only on purpose (PowerShell 5.1 reads .ps1 as ANSI without BOM).
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$clientId = '178c6fc778ccc68e1d6a'   # public GitHub CLI OAuth client_id
$body = @{
    client_id = $clientId
    scope     = 'repo read:org gist'
}

function Invoke-DeviceCode {
    param($Body, $Attempts = 8)
    for ($i = 1; $i -le $Attempts; $i++) {
        try {
            return Invoke-RestMethod -Method Post `
                -Uri 'https://github.com/login/device/code' `
                -Headers @{ 'Accept' = 'application/json' } `
                -Body $Body -TimeoutSec 20
        } catch {
            Write-Host ("  attempt {0} failed: {1}" -f $i, $_.Exception.Message)
            Start-Sleep -Seconds 2
        }
    }
    throw 'cannot reach github.com/login/device/code (network blocked)'
}

$res = Invoke-DeviceCode -Body $body

$state = @{
    device_code = $res.device_code
    interval    = $res.interval
    expires_at  = (Get-Date).AddSeconds($res.expires_in).ToString('o')
} | ConvertTo-Json
$state | Set-Content -Path "$env:TEMP\gh_device.json" -Encoding UTF8

try { Set-Clipboard -Value $res.user_code } catch {}
Start-Process $res.verification_uri

Write-Host ''
Write-Host '=============== AUTHORIZE IN THE BROWSER ==============='
Write-Host ("  CODE    : {0}" -f $res.user_code)
Write-Host ("  URL     : {0}" -f $res.verification_uri)
Write-Host ("  EXPIRES : {0} minutes" -f [math]::Round($res.expires_in / 60, 0))
Write-Host '  (code already copied to clipboard: just Ctrl+V)'
Write-Host '========================================================'
