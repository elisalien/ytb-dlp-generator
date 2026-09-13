# Recree le raccourci "yt-dlp Studio" (dossier + Bureau), pinable a la barre des taches.
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$ico = Join-Path $root 'assets\yt-dlp-studio.ico'
$launch = Join-Path $root 'launch.bat'

if (-not (Test-Path -LiteralPath $ico)) {
    Write-Host "Icone manquante : assets\yt-dlp-studio.ico"
    exit 1
}
if (-not (Test-Path -LiteralPath $launch)) {
    Write-Host "launch.bat introuvable."
    exit 1
}

$ws = New-Object -ComObject WScript.Shell

function New-StudioShortcut([string]$path) {
    $sc = $ws.CreateShortcut($path)
    $sc.TargetPath = Join-Path $env:SystemRoot 'System32\cmd.exe'
    $sc.Arguments = "/c `"$launch`""
    $sc.WorkingDirectory = $root
    $sc.IconLocation = "$ico,0"
    $sc.Description = 'yt-dlp Studio - telechargeur et convertisseur video'
    $sc.WindowStyle = 7
    $sc.Save()
    Write-Host "OK  $path"
}

New-StudioShortcut (Join-Path $root 'yt-dlp Studio.lnk')
$desktop = [Environment]::GetFolderPath('Desktop')
New-StudioShortcut (Join-Path $desktop 'yt-dlp Studio.lnk')

Write-Host ""
Write-Host "Raccourci pret. Clic droit -> Epingler a la barre des taches."
