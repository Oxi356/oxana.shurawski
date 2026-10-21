# Holt aktuelle KI-News von der New York Times und speichert sie in data/news.json.
# Der Schlüssel landet nie auf der Website: Auf dem Laptop kommt er aus der Datei .env,
# bei GitHub aus dem Secret NYT_API_KEY.
# Starten im Terminal:  powershell -ExecutionPolicy Bypass -File news-widget\fetch-news.ps1

# Die .env liegt hier im selben Ordner wie das Skript, die Website einen Ordner darüber
$ordner = Split-Path -Parent $PSScriptRoot
$key = $env:NYT_API_KEY

# Kein Secret da? Dann NYT_API_KEY aus der .env lesen
if (-not $key) {
  $envDatei = Join-Path $PSScriptRoot '.env'
  if (-not (Test-Path $envDatei)) { Write-Host 'Keine .env in diesem Ordner gefunden.'; exit 1 }
  $zeile = Get-Content $envDatei | Where-Object { $_ -match '^\s*NYT_API_KEY\s*=' } | Select-Object -First 1
  $key = if ($zeile) { ($zeile -split '=', 2)[1].Trim().Trim('"') } else { '' }
}
# Aufräumen, falls beim Kopieren etwas mitgerutscht ist (Leerzeichen, Zeilenumbruch, Anführungszeichen, 'NYT_API_KEY=')
$key = ($key -replace '^\s*NYT_API_KEY\s*=', '').Trim().Trim('"', "'").Trim()
if (-not $key -or $key -eq 'hier-deinen-schluessel-eintragen') { Write-Host 'Es fehlt dein echter NYT_API_KEY.'; exit 1 }
$quelle = if ($env:NYT_API_KEY) { 'GitHub-Secret' } else { '.env' }
Write-Host "Schluessel aus $quelle gelesen: $($key.Length) Zeichen."

$suche = [uri]::EscapeDataString('artificial intelligence')

# Die NYT findet auch Artikel, in denen KI nur am Rand vorkommt.
# Deshalb holen wir 3 Seiten (30 Artikel) und behalten nur echte KI-Themen.
$kiMuster = 'artificial intelligence|\bA\.I\.|\bAI\b|chatbot|ChatGPT|OpenAI|Anthropic|Claude|Gemini|machine learning|neural|robot|algorithm|deepfake|Nvidia'
$news = @()
foreach ($seite in 0..2) {
  $url = "https://api.nytimes.com/svc/search/v2/articlesearch.json?q=$suche&sort=newest&page=$seite&api-key=$key"
  try {
    $antwort = Invoke-RestMethod -Uri $url
  } catch {
    Write-Host "Die NYT hat nicht geantwortet: $($_.Exception.Message)"
    if ($_.ErrorDetails.Message) { Write-Host "Antwort der NYT: $($_.ErrorDetails.Message)" }
    Write-Host 'Pruefe den Schluessel und ob die Article Search API in deiner App aktiviert ist.'
    exit 1
  }
  foreach ($d in $antwort.response.docs) {
    $themen = ($d.keywords | ForEach-Object { $_.value }) -join ' '
    $text = "$($d.headline.main) $($d.abstract) $themen"
    if ($text -match $kiMuster -and $news.Count -lt 8) {
      $news += [pscustomobject]@{
        title   = $d.headline.main
        url     = $d.web_url
        summary = $d.abstract
        date    = $d.pub_date.Substring(8, 2) + '.' + $d.pub_date.Substring(5, 2) + '.'
      }
    }
  }
  if ($news.Count -ge 8) { break }
  Start-Sleep -Seconds 13   # die NYT erlaubt nur 5 Abfragen pro Minute
}

$ziel = Join-Path $ordner 'data'
New-Item -ItemType Directory -Force $ziel | Out-Null
$json = ConvertTo-Json @($news) -Depth 3
[IO.File]::WriteAllText((Join-Path $ziel 'news.json'), $json, (New-Object Text.UTF8Encoding $false))

Write-Host "Fertig: $(@($news).Count) Schlagzeilen in data\news.json gespeichert."
