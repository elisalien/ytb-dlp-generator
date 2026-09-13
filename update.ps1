# Installe ou met a jour yt-dlp (nightly), Deno et FFmpeg dans .\bin
# Telecharge depuis les depots officiels. Ne s'appuie pas sur --update-to
# (le self-updater Windows rate souvent le switch stable -> nightly).
# Appele par install.bat (premiere installation), update.bat et server.ps1 (-Auto).
# -Auto : ne verifie qu'une fois toutes les 12h.
param([switch]$Auto)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls13 } catch {}
$ProgressPreference = 'SilentlyContinue'

$Root = $PSScriptRoot
$Bin = Join-Path $Root 'bin'
$UserAgent = 'Mozilla/5.0 yt-dlp-studio-update'
$failed = $false

function Write-Ok([string]$msg)  { Write-Host "       $msg" }
function Write-Err([string]$msg) { Write-Host "       ERREUR : $msg"; $script:failed = $true }

function Get-ToolOutput([string]$exe, [string[]]$argList) {
    if (-not (Test-Path -LiteralPath $exe)) { return '' }
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        return (& $exe @argList 2>&1 | Out-String)
    } catch {
        return ''
    } finally {
        $ErrorActionPreference = $prev
    }
}

function Get-ToolVersion([string]$exe, [string[]]$argList) {
    $line = (Get-ToolOutput $exe $argList) -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -First 1
    if ($line) { return $line.Trim() }
    return $null
}

function Wait-ToolVersion([string]$exe, [string[]]$argList) {
    foreach ($i in 1..8) {
        $v = Get-ToolVersion $exe $argList
        if ($v) { return $v }
        Start-Sleep -Milliseconds 250
    }
    return $null
}

# Remplace $dest par $source ; restaure l'ancien fichier si le deplacement echoue.
function Replace-File([string]$source, [string]$dest) {
    $bak = "$dest.bak"
    if (Test-Path -LiteralPath $dest) {
        Move-Item -LiteralPath $dest -Destination $bak -Force
    }
    try {
        Move-Item -LiteralPath $source -Destination $dest -Force
    } catch {
        if (Test-Path -LiteralPath $bak) { Move-Item -LiteralPath $bak -Destination $dest -Force }
        throw
    }
    # Un .exe en cours d'utilisation peut etre renomme mais pas supprime : on ignore.
    Remove-Item -LiteralPath $bak -Force -ErrorAction SilentlyContinue
}

function Get-WebText([string]$url) {
    $content = (Invoke-WebRequest -Uri $url -UseBasicParsing -UserAgent $UserAgent).Content
    if ($content -is [byte[]]) { $content = [Text.Encoding]::UTF8.GetString($content) }
    return ([string]$content).Trim()
}

function Download-File([string]$url, [string]$dest) {
    Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -UserAgent $UserAgent
}

# Telecharge une archive zip et installe les fichiers demandes.
# $targets : nom du fichier dans l'archive -> chemin final.
function Install-FromZip([string]$url, [hashtable]$targets) {
    $tag = [IO.Path]::GetRandomFileName()
    $zip = Join-Path $Bin "$tag.zip"
    $tmpDir = Join-Path $Bin "$tag.tmp"
    try {
        Download-File $url $zip
        Expand-Archive -LiteralPath $zip -DestinationPath $tmpDir -Force
        foreach ($name in $targets.Keys) {
            $found = Get-ChildItem -LiteralPath $tmpDir -Recurse -Filter $name | Select-Object -First 1
            if (-not $found) { throw "$name introuvable dans l'archive" }
            Replace-File $found.FullName $targets[$name]
        }
    } finally {
        Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if (-not (Test-Path -LiteralPath $Bin)) { New-Item -ItemType Directory -Path $Bin | Out-Null }

$Stamp = Join-Path $Bin '.last-update'
if ($Auto -and (Test-Path -LiteralPath $Stamp)) {
    $age = (Get-Date) - (Get-Item -LiteralPath $Stamp).LastWriteTime
    if ($age.TotalHours -lt 12) {
        Write-Host ''
        Write-Host ('   Outils verifies il y a ' + [int]$age.TotalMinutes + ' min - check ignore.')
        Write-Host '   (Pour forcer maintenant : double-clic sur update.bat)'
        Write-Host ''
        exit 0
    }
}

Write-Host '============================================================'
Write-Host '   yt-dlp Studio - Outils (installation / mise a jour)'
Write-Host '============================================================'
Write-Host ''
Write-Host ' Installe ce qui manque et ne met a jour que si necessaire :'
Write-Host '   - yt-dlp   (canal nightly GitHub)'
Write-Host '   - Deno     (auto-mise a jour native, repli zip)'
Write-Host '   - FFmpeg   (re-telecharge seulement si plus recent)'
Write-Host ''

# --- yt-dlp nightly (telechargement direct, pas le self-updater) ---
Write-Host '[1/3] yt-dlp (canal nightly)...'
$ydl = Join-Path $Bin 'yt-dlp.exe'
$before = Get-ToolVersion $ydl @('--version')
try {
    # La version nightly est le nom du tag GitHub : on evite de telecharger 18 Mo pour rien.
    $latest = $null
    try {
        $latest = [string](Invoke-RestMethod -Uri 'https://api.github.com/repos/yt-dlp/yt-dlp-nightly-builds/releases/latest' -UserAgent $UserAgent -TimeoutSec 20).tag_name
    } catch {}
    if ($before -and $latest -and $before -eq $latest) {
        Write-Ok "Deja a jour : $before"
    } else {
        $tmp = "$ydl.new"
        Download-File 'https://github.com/yt-dlp/yt-dlp-nightly-builds/releases/latest/download/yt-dlp.exe' $tmp
        if ((Get-Item -LiteralPath $tmp).Length -lt 5MB) {
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
            throw 'telechargement yt-dlp trop petit (page d''erreur GitHub ?)'
        }
        if ((Test-Path -LiteralPath $ydl) -and (Get-FileHash -LiteralPath $tmp).Hash -eq (Get-FileHash -LiteralPath $ydl).Hash) {
            Remove-Item -LiteralPath $tmp -Force
            Write-Ok "Deja a jour : $before"
        } else {
            Replace-File $tmp $ydl
            $after = Wait-ToolVersion $ydl @('--version')
            if (-not $after) { throw 'yt-dlp.exe telecharge mais ne demarre pas' }
            Write-Ok ('Mis a jour : ' + $(if ($before) { $before } else { '(absent)' }) + ' -> ' + $after)
        }
    }
} catch {
    Write-Err $_.Exception.Message
    Write-Ok 'Si un telechargement est en cours, arretez yt-dlp Studio puis relancez update.bat.'
}

Write-Host ''

# --- Deno ---
Write-Host '[2/3] Deno...'
$deno = Join-Path $Bin 'deno.exe'
Remove-Item -LiteralPath (Join-Path $Bin 'deno.old.exe') -Force -ErrorAction SilentlyContinue
$denoBefore = Get-ToolVersion $deno @('--version')
$denoOk = $false
if ($denoBefore) {
    try {
        & $deno upgrade
        $denoOk = ($LASTEXITCODE -eq 0)
    } catch {
        $denoOk = $false
    }
}
if (-not $denoOk) {
    try {
        Install-FromZip 'https://github.com/denoland/deno/releases/latest/download/deno-x86_64-pc-windows-msvc.zip' @{ 'deno.exe' = $deno }
        $denoOk = $true
        Write-Ok 'Deno installe depuis GitHub.'
    } catch {
        Write-Err $_.Exception.Message
    }
}
if ($denoOk) {
    $denoAfter = Get-ToolVersion $deno @('--version')
    if ($denoAfter -and $denoBefore -eq $denoAfter) { Write-Ok "Deja a jour : $denoAfter" }
    elseif ($denoAfter) { Write-Ok "OK : $denoAfter" }
}

Write-Host ''

# --- FFmpeg (+ ffprobe) ---
Write-Host '[3/3] FFmpeg...'
$ffmpeg = Join-Path $Bin 'ffmpeg.exe'
$lv = if ((Get-ToolVersion $ffmpeg @('-version')) -match 'ffmpeg version (\S+)') { $Matches[1] } else { '' }
# Build "full" obligatoire : la build "essentials" n'a pas l'encodeur HAP (libsnappy).
$hasHap = $lv -and ((Get-ToolOutput $ffmpeg @('-hide_banner', '-encoders')) -match '\bhap\b')
$rv = ''
try { $rv = Get-WebText 'https://www.gyan.dev/ffmpeg/builds/release-version' } catch {}
if ($lv) { Write-Ok "Version installee : $lv" }
if ($hasHap -and -not $rv) {
    Write-Ok 'Derniere version introuvable en ligne : FFmpeg conserve.'
} elseif ($hasHap -and $lv -like "*$rv*") {
    Write-Ok "FFmpeg est a jour ($rv)."
} else {
    Write-Ok $(if (-not $lv) { 'Installation (environ 200 Mo, patientez)...' }
        elseif (-not $hasHap) { 'Build sans encodeur HAP : installation de la build complete...' }
        else { "Mise a jour vers $rv..." })
    try {
        Install-FromZip 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-full.zip' @{
            'ffmpeg.exe'  = $ffmpeg
            'ffprobe.exe' = (Join-Path $Bin 'ffprobe.exe')
        }
        $after = Get-ToolVersion $ffmpeg @('-version')
        Write-Ok ('FFmpeg installe : ' + $(if ($after -match 'ffmpeg version (\S+)') { $Matches[1] } else { '?' }))
    } catch {
        Write-Err $_.Exception.Message
    }
}

Write-Host ''
Write-Host '============================================================'
if ($failed) {
    Write-Host '   Operation INCOMPLETE. Relancez update.bat.'
    Write-Host '============================================================'
    exit 1
}
Set-Content -LiteralPath $Stamp -Value (Get-Date -Format o) -Encoding ascii -ErrorAction SilentlyContinue
Write-Host '   Outils prets.'
Write-Host '============================================================'
exit 0
