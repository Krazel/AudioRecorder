param(
  [string]$GhPath = "..\gh.bat",
  [string]$ApiDir = "..\APIs\IOS",
  [string]$AppleTeamId = "B2X6D3A9J9",
  [string]$Environment = "app-store-production"
)

$ErrorActionPreference = "Stop"

$keyIdPath = Join-Path $ApiDir "Key ID.txt"
$issuerIdPath = Join-Path $ApiDir "Issuer ID.txt"
$privateKeyPath = Join-Path $ApiDir "Coder Metadata App Manager.p8"

if (-not (Test-Path $GhPath)) {
  throw "No encuentro gh en $GhPath"
}

foreach ($path in @($keyIdPath, $issuerIdPath, $privateKeyPath)) {
  if (-not (Test-Path $path)) {
    throw "No encuentro $path"
  }
}

$keyId = (Get-Content -Raw $keyIdPath).Trim()
$issuerId = (Get-Content -Raw $issuerIdPath).Trim()
$privateKeyBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path $privateKeyPath)))

& $GhPath auth status
if ($LASTEXITCODE -ne 0) {
  throw "gh no esta autenticado. Ejecuta ..\gh.bat auth login y vuelve a lanzar este script."
}

$AppleTeamId | & $GhPath secret set --env $Environment APPLE_TEAM_ID
$keyId | & $GhPath secret set --env $Environment ASC_KEY_ID
$issuerId | & $GhPath secret set --env $Environment ASC_ISSUER_ID
$privateKeyBase64 | & $GhPath secret set --env $Environment ASC_PRIVATE_KEY_BASE64

Write-Host "Secrets de App Store Connect actualizados en el environment '$Environment'."
