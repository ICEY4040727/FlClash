param(
    [string]$SshHost = $env:FLCLASH_SERVER_HOST,
    [string]$User = $(if ($env:FLCLASH_SERVER_USER) { $env:FLCLASH_SERVER_USER } else { "azureuser" }),
    [string]$KeyPath = "$env:USERPROFILE\.ssh\vps_key.pem",
    [string]$ConfigPath = "/etc/sing-box/config.json",
    [string]$Out = "$env:APPDATA\com.follow\clash\server-chain.json"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($SshHost)) {
    throw "Pass -SshHost <ip-or-host> or set `$env:FLCLASH_SERVER_HOST"
}

if (-not (Test-Path -LiteralPath $KeyPath)) {
    throw "SSH key not found: $KeyPath"
}

$remoteCommand = "sudo -n cat $ConfigPath"
$raw = ssh -i $KeyPath -o BatchMode=yes -o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new "$User@$SshHost" $remoteCommand
if ($LASTEXITCODE -ne 0) {
    throw "ssh failed with exit code $LASTEXITCODE"
}

$text = ($raw -join "`n").Trim()
if ([string]::IsNullOrWhiteSpace($text)) {
    throw "empty config returned (does sudo need a password?)"
}

$doc = $text | ConvertFrom-Json
if ($null -eq $doc.inbounds -and $null -eq $doc.endpoints -and $null -eq $doc.outbounds) {
    throw "unexpected config: no inbounds/endpoints/outbounds"
}

$inbounds = @()
foreach ($item in @($doc.inbounds)) {
    if ($null -eq $item) { continue }
    $inbounds += [ordered]@{
        type   = $item.type
        listen = $item.listen
        port   = $item.listen_port
        tls    = ($null -ne $item.tls)
        cert   = $item.tls.certificate_path
    }
}

$endpoints = @()
foreach ($item in @($doc.endpoints)) {
    if ($null -eq $item) { continue }
    $endpoints += [ordered]@{
        type      = $item.type
        tag       = $item.tag
        addresses = @($item.address)
        mtu       = $item.mtu
    }
}

$outbounds = @()
foreach ($item in @($doc.outbounds)) {
    if ($null -eq $item) { continue }
    $outbounds += [ordered]@{
        type = $item.type
        tag  = $item.tag
    }
}

$keep = @(
    "action", "outbound", "protocol", "ip_is_private", "domain_suffix",
    "domain_keyword", "rule_set", "inbound", "network"
)
$rules = @()
foreach ($rule in @($doc.route.rules)) {
    if ($null -eq $rule) { continue }
    $entry = [ordered]@{}
    foreach ($name in $keep) {
        $value = $rule.$name
        if ($null -ne $value) { $entry[$name] = $value }
    }
    $rules += $entry
}

$payload = [ordered]@{
    generatedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    host        = $SshHost
    inbounds    = $inbounds
    endpoints   = $endpoints
    outbounds   = $outbounds
    final       = $doc.route.final
    rules       = $rules
}

$dir = Split-Path -Parent $Out
if (-not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
}
Set-Content -LiteralPath $Out -Value ($payload | ConvertTo-Json -Depth 8) -Encoding utf8
Write-Host "written: $Out"
Write-Host ("inbounds: " + (($inbounds | ForEach-Object { "$($_.type):$($_.port)" }) -join ", "))
Write-Host ("endpoints: " + (($endpoints | ForEach-Object { "$($_.tag)($($_.type))" }) -join ", ") + "  final: $($payload.final)")
