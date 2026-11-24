param(
    [string]$SshHost = "4.216.184.217",
    [string]$User = "azureuser",
    [string]$KeyPath = "$env:USERPROFILE\.ssh\vps_key.pem",
    [string]$ConfigPath = "/etc/sing-box/config.json",
    [string]$Out = "$env:APPDATA\com.follow\clash\server-chain.json"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $KeyPath)) {
    throw "SSH key not found: $KeyPath"
}

$remote = @'
import json, sys
path = sys.argv[1]
try:
    doc = json.load(open(path))
except PermissionError:
    sys.exit("permission denied: run with passwordless sudo on the server")
summary = {"inbounds": [], "endpoints": [], "outbounds": [], "final": None, "rules": []}
for item in doc.get("inbounds") or []:
    tls = item.get("tls") or {}
    summary["inbounds"].append({
        "type": item.get("type"),
        "listen": item.get("listen"),
        "port": item.get("listen_port"),
        "tls": bool(tls),
        "cert": tls.get("certificate_path"),
    })
for item in doc.get("endpoints") or []:
    summary["endpoints"].append({
        "type": item.get("type"),
        "tag": item.get("tag"),
        "addresses": item.get("address") or [],
        "mtu": item.get("mtu"),
    })
for item in doc.get("outbounds") or []:
    summary["outbounds"].append({"type": item.get("type"), "tag": item.get("tag")})
route = doc.get("route") or {}
summary["final"] = route.get("final")
keep = ("action", "outbound", "protocol", "ip_is_private", "domain_suffix",
        "domain_keyword", "rule_set", "inbound", "network")
for rule in route.get("rules") or []:
    summary["rules"].append({k: v for k, v in rule.items() if k in keep})
print(json.dumps(summary, ensure_ascii=False))
'@

$encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($remote))
$remoteCommand = "echo $encoded | base64 -d > /tmp/singbox-summary.py && sudo -n python3 /tmp/singbox-summary.py $ConfigPath; rc=`$?; rm -f /tmp/singbox-summary.py; exit `$rc"

$raw = ssh -i $KeyPath -o BatchMode=yes -o ConnectTimeout=15 "$User@$SshHost" $remoteCommand
if ($LASTEXITCODE -ne 0) {
    throw "ssh/summary failed with exit code $LASTEXITCODE"
}

$summary = $raw | ConvertFrom-Json
$payload = [ordered]@{
    generatedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    host        = $SshHost
    inbounds    = $summary.inbounds
    endpoints   = $summary.endpoints
    outbounds   = $summary.outbounds
    final       = $summary.final
    rules       = $summary.rules
}

$json = $payload | ConvertTo-Json -Depth 8
$dir = Split-Path -Parent $Out
if (-not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
}
Set-Content -LiteralPath $Out -Value $json -Encoding utf8
Write-Host "written: $Out"
Write-Host ("inbounds: " + (($payload.inbounds | ForEach-Object { "$($_.type):$($_.port)" }) -join ", "))
Write-Host ("endpoints: " + (($payload.endpoints | ForEach-Object { "$($_.tag)($($_.type))" }) -join ", ") + "  final: $($payload.final)")
