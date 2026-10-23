# Schreibt config.js mit der n8n-Webhook-Adresse, damit das Kontaktformular weiß, wohin es senden soll.
# Die Adresse steht nur in der .env (bei GitHub im Secret N8N_WEBHOOK_URL), nicht im Code der Seite.
# Starten im Terminal:  powershell -ExecutionPolicy Bypass -File kontaktformular\make-config.ps1

# Die .env liegt hier im selben Ordner wie das Skript, die Website einen Ordner darüber
$ordner = Split-Path -Parent $PSScriptRoot
$url = $env:N8N_WEBHOOK_URL

# Kein Secret da? Dann N8N_WEBHOOK_URL aus der .env lesen
if (-not $url) {
  $envDatei = Join-Path $PSScriptRoot '.env'
  if (-not (Test-Path $envDatei)) { Write-Host 'Keine .env in diesem Ordner gefunden.'; exit 1 }
  $zeile = Get-Content $envDatei | Where-Object { $_ -match '^\s*N8N_WEBHOOK_URL\s*=' } | Select-Object -First 1
  $url = if ($zeile) { ($zeile -split '=', 2)[1] } else { '' }
}
$url = $url.Trim().Trim('"', "'").Trim()
if ($url -notmatch '^https://') { Write-Host 'In der .env fehlt N8N_WEBHOOK_URL (sie muss mit https:// anfangen).'; exit 1 }

$inhalt = "// Automatisch aus der .env erzeugt von make-config.ps1. Nicht von Hand bearbeiten.`nwindow.N8N_WEBHOOK = '$url';`n"
[IO.File]::WriteAllText((Join-Path $ordner 'config.js'), $inhalt, (New-Object Text.UTF8Encoding $false))
$art = if ($url -match '/webhook-test/') { 'TEST-Adresse (nur waehrend "Listen for test event" in n8n)' } else { 'Production-Adresse (Workflow muss aktiv sein)' }
Write-Host "Fertig: config.js geschrieben, Formular sendet an die $art."
