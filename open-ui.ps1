# Ouvre l'interface dans un vrai navigateur (pas l'editeur associe aux .html).
# Firefox est prioritaire : l'app utilise --cookies-from-browser firefox,
# autant que l'UI et les cookies soient au meme endroit.
# -Url : adresse du serveur local (server.ps1). Sans -Url : index.html en fichier.
param([string]$Url)
$ErrorActionPreference = 'SilentlyContinue'
if ($Url) {
    $url = $Url
} else {
    $page = Join-Path $PSScriptRoot 'index.html'
    if (-not (Test-Path -LiteralPath $page)) {
        Write-Host "index.html introuvable."
        exit 1
    }
    $url = ([Uri]$page).AbsoluteUri
}

$exe = $null

# 1) Firefox en priorite
$firefoxPaths = @(
    "$env:ProgramFiles\Mozilla Firefox\firefox.exe",
    "${env:ProgramFiles(x86)}\Mozilla Firefox\firefox.exe",
    "$env:LocalAppData\Mozilla Firefox\firefox.exe"
)
foreach ($cand in $firefoxPaths) {
    if (Test-Path -LiteralPath $cand) { $exe = $cand; break }
}

# 2) Sinon : navigateur par defaut du systeme
if (-not $exe) {
    $progId = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoice').ProgId
    if ($progId) {
        $cmd = (Get-ItemProperty "Registry::HKEY_CLASSES_ROOT\$progId\shell\open\command").'(default)'
        if ($cmd -match '"([^"]+\.exe)"') {
            $candidate = $Matches[1]
            if (Test-Path -LiteralPath $candidate) { $exe = $candidate }
        }
    }
}

# 3) Sinon : autres navigateurs connus
if (-not $exe) {
    $candidates = @(
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "$env:LocalAppData\Google\Chrome\Application\chrome.exe"
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
