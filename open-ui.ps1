# Ouvre index.html dans un vrai navigateur (pas l'editeur associe aux .html).
$ErrorActionPreference = 'SilentlyContinue'
$page = Join-Path $PSScriptRoot 'index.html'
if (-not (Test-Path -LiteralPath $page)) {
    Write-Host "index.html introuvable."
    exit 1
}
$url = ([Uri]$page).AbsoluteUri

$exe = $null
$progId = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoice').ProgId
if ($progId) {
    $cmd = (Get-ItemProperty "Registry::HKEY_CLASSES_ROOT\$progId\shell\open\command").'(default)'
    if ($cmd -match '"([^"]+\.exe)"') { $exe = $Matches[1] }
}

if (-not ($exe -and (Test-Path -LiteralPath $exe))) {
    $candidates = @(
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "$env:LocalAppData\Google\Chrome\Application\chrome.exe",
        "$env:ProgramFiles\Mozilla Firefox\firefox.exe"
    )
    foreach ($cand in $candidates) {
        if (Test-Path -LiteralPath $cand) { $exe = $cand; break }
    }
}

if ($exe) {
    Start-Process -FilePath $exe -ArgumentList $url
} else {
    Start-Process $url
}
