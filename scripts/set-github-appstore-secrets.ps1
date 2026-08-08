param(
  [string]$GhPath = "gh.exe",
  [string]$ApiDir = "..\APIs\IOS",
  [string]$AppleTeamId = "B2X6D3A9J9",
  [string]$Environment = "app-store-production",
  [string]$Repository = "Krazel/AudioRecorder"
)

$ErrorActionPreference = "Stop"

$keyIdPath = Join-Path $ApiDir "Key ID.txt"
$issuerIdPath = Join-Path $ApiDir "Issuer ID.txt"
$privateKeyPath = Join-Path $ApiDir "Coder Metadata App Manager.p8"

$ghCommand = Get-Command $GhPath -ErrorAction SilentlyContinue
if (-not $ghCommand) {
  throw "No encuentro GitHub CLI ($GhPath)"
}
$ghExecutable = $ghCommand.Source

foreach ($path in @($keyIdPath, $issuerIdPath, $privateKeyPath)) {
  if (-not (Test-Path $path)) {
    throw "No encuentro $path"
  }
}

$keyId = (Get-Content -Raw $keyIdPath).Trim()
$issuerId = (Get-Content -Raw $issuerIdPath).Trim()
$privateKeyText = (Get-Content -Raw $privateKeyPath).Trim()

if ($AppleTeamId -notmatch '^[A-Z0-9]{10}$') {
  throw "APPLE_TEAM_ID no tiene el formato esperado"
}
if ($keyId -notmatch '^[A-Z0-9]{10}$') {
  throw "Key ID no tiene el formato esperado"
}
if ($issuerId -notmatch '^[0-9a-fA-F-]{36}$') {
  throw "Issuer ID no tiene el formato esperado"
}
if (-not ($privateKeyText.StartsWith('-----BEGIN PRIVATE KEY-----') -and $privateKeyText.EndsWith('-----END PRIVATE KEY-----'))) {
  throw "El archivo p8 no parece una clave privada válida"
}

$privateKeyBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path $privateKeyPath)))

& $ghExecutable auth status
if ($LASTEXITCODE -ne 0) {
  throw "gh no esta autenticado. Ejecuta gh auth login y vuelve a lanzar este script."
}

& $ghExecutable api --method PUT "repos/$Repository/environments/$Environment" | Out-Null
if ($LASTEXITCODE -ne 0) {
  throw "No se pudo preparar el environment '$Environment' en $Repository"
}

function Set-GitHubEnvironmentSecret {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$Value
  )

  $startInfo = [Diagnostics.ProcessStartInfo]::new()
  $startInfo.FileName = $ghExecutable
  $startInfo.Arguments = "secret set --repo $Repository --env $Environment $Name"
  $startInfo.UseShellExecute = $false
  $startInfo.RedirectStandardInput = $true
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true

  $process = [Diagnostics.Process]::Start($startInfo)
  $secretBytes = [Text.Encoding]::ASCII.GetBytes($Value)
  $process.StandardInput.BaseStream.Write($secretBytes, 0, $secretBytes.Length)
  $process.StandardInput.Close()
  $process.WaitForExit()
  if ($process.ExitCode -ne 0) {
    throw "No se pudo actualizar el secret '$Name': $($process.StandardError.ReadToEnd())"
  }
}

Set-GitHubEnvironmentSecret -Name APPLE_TEAM_ID -Value $AppleTeamId
Set-GitHubEnvironmentSecret -Name ASC_KEY_ID -Value $keyId
Set-GitHubEnvironmentSecret -Name ASC_ISSUER_ID -Value $issuerId
Set-GitHubEnvironmentSecret -Name ASC_PRIVATE_KEY_BASE64 -Value $privateKeyBase64

Write-Host "Secrets de App Store Connect actualizados en el environment '$Environment'."
