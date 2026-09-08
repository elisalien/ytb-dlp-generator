# Met a jour yt-dlp (nightly), Deno et FFmpeg dans .\bin
# Telecharge depuis les depots officiels. Ne s'appuie pas sur --update-to
# (le self-updater Windows rate souvent le switch stable -> nightly).
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls13 } catch {}
$ProgressPreference = 'SilentlyContinue'

$Root = $PSScriptRoot
$Bin = Join-Path $Root 'bin'
$failed = $false

function Write-Step([string]$msg) { Write-Host $msg }
function Write-Ok([string]$msg)   { Write-Host "       $msg" }
function Write-Err([string]$msg)  { Write-Host "       ERREUR : $msg"; $script:failed = $true }

function Get-ToolVersion([string]$exe, [string[]]$argList) {
    if (-not (Test-Path -LiteralPath $exe)) { return $null }
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = & $exe @argList 2>&1 | Out-String
        $line = ($out -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -First 1)
        if ($line) { return $line.Trim() }
        return $null
    } catch {
        return $null
    } finally {
        $ErrorActionPreference = $prev
    }
}

function Wait-ToolVersion([string]$exe, [string[]]$argList) {
    foreach ($i in 1..8) {
        $v = Get-ToolVersion $exe $argList
        if ($v) { return $v }
        Start-Sleep -Milliseconds 250
    }
    return $null
}

function Replace-File([string]$source, [string]$dest) {
    $bak = "$dest.bak"
    if (Test-Path -LiteralPath $dest) {
        Move-Item -LiteralPath $dest -Destination $bak -Force
    }
    try {
        Move-Item -LiteralPath $source -Destination $dest -Force
        if (Test-Path -LiteralPath $bak) { Remove-Item -LiteralPath $bak -Force }
    } catch {
        if (Test-Path -LiteralPath $bak) {
            Move-Item -LiteralPath $bak -Destination $dest -Force
        }
        throw
    }
}

function Get-WebText([string]$url) {
    $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -UserAgent 'Mozilla/5.0 yt-dlp-studio-update'
    $content = $resp.Content
    if ($content -is [byte[]]) {
        return [System.Text.Encoding]::UTF8.GetString($content).Trim()
    }
    return ([string]$content).Trim()
}

function Download-File([string]$url, [string]$dest) {
    Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -UserAgent 'Mozilla/5.0 yt-dlp-studio-update'
}

if (-not (Test-Path -LiteralPath $Bin)) { New-Item -ItemType Directory -Path $Bin | Out-Null }

Write-Host '============================================================'
Write-Host '   yt-dlp Studio - Mise a jour des outils'
Write-Host '============================================================'
Write-Host ''
Write-Host ' Verifie et met a jour, uniquement si necessaire :'
Write-Host '   - yt-dlp   (canal nightly GitHub)'
Write-Host '   - Deno     (auto-mise a jour native, repli zip)'
Write-Host '   - FFmpeg   (re-telecharge seulement si plus recent)'
Write-Host ''

# --- yt-dlp nightly (telechargement direct, pas le self-updater) ---
Write-Step '[1/3] yt-dlp (canal nightly)...'
$ydl = Join-Path $Bin 'yt-dlp.exe'
$ydlUrl = 'https://github.com/yt-dlp/yt-dlp-nightly-builds/releases/latest/download/yt-dlp.exe'
$before = Get-ToolVersion $ydl @('--version')
try {
    $tmp = Join-Path $Bin 'yt-dlp.exe.new'
    Download-File $ydlUrl $tmp
    if ((Get-Item -LiteralPath $tmp).Length -lt 5MB) {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        throw 'telechargement yt-dlp trop petit (page d''erreur GitHub ?)'
    }
    $same = $false
    if (Test-Path -LiteralPath $ydl) {
        $same = (Get-FileHash -LiteralPath $tmp -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $ydl -Algorithm SHA256).Hash
    }
    if ($same) {
        Remove-Item -LiteralPath $tmp -Force
        Write-Ok ("Deja a jour : " + $(if ($before) { $before } else { '?' }))
    } else {
        Replace-File $tmp $ydl
        $after = Wait-ToolVersion $ydl @('--version')
        if (-not $after) { throw 'yt-dlp.exe telecharge mais ne demarre pas' }
        Write-Ok ("Mis a jour : " + $(if ($before) { $before } else { '(absent)' }) + ' -> ' + $after)
    }
} catch {
    Write-Err $_.Exception.Message
    Write-Ok 'Ferme le Terminal yt-dlp Studio si un telechargement est en cours, puis relance.'
}

Write-Host ''

# --- Deno ---
Write-Step '[2/3] Deno...'
$deno = Join-Path $Bin 'deno.exe'
Remove-Item -LiteralPath (Join-Path $Bin 'deno.old.exe') -Force -ErrorAction SilentlyContinue
$denoBefore = Get-ToolVersion $deno @('--version')
$denoOk = $false
if (Test-Path -LiteralPath $deno) {
    try {
        & $deno upgrade
        if ($LASTEXITCODE -eq 0) { $denoOk = $true }
    } catch {
        $denoOk = $false
    }
}
if (-not $denoOk) {
    try {
        $zip = Join-Path $Root 'deno.zip'
        Download-File 'https://github.com/denoland/deno/releases/latest/download/deno-x86_64-pc-windows-msvc.zip' $zip
        $tmpDir = Join-Path $Root 'deno_tmp'
        if (Test-Path -LiteralPath $tmpDir) { Remove-Item -LiteralPath $tmpDir -Recurse -Force }
        Expand-Archive -Path $zip -DestinationPath $tmpDir -Force
        $fresh = Get-ChildItem -LiteralPath $tmpDir -Recurse -Filter 'deno.exe' | Select-Object -First 1
        if (-not $fresh) { throw 'deno.exe introuvable dans le zip' }
        Replace-File $fresh.FullName $deno
        Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
        $denoOk = $true
        Write-Ok 'Deno reinstalle depuis GitHub.'
    } catch {
        Write-Err $_.Exception.Message
    }
}
if ($denoOk) {
    $denoAfter = Get-ToolVersion $deno @('--version')
    if ($denoBefore -and $denoAfter -and ($denoBefore -eq $denoAfter)) {
        Write-Ok ("Deja a jour : " + ($denoAfter -split "`n")[0])
    } elseif ($denoAfter) {
        Write-Ok ("OK : " + ($denoAfter -split "`n")[0])
    }
}

Write-Host ''

# --- FFmpeg ---
Write-Step '[3/3] FFmpeg...'
$ffmpeg = Join-Path $Bin 'ffmpeg.exe'
$ffprobe = Join-Path $Bin 'ffprobe.exe'
$localLine = Get-ToolVersion $ffmpeg @('-version')
if ($localLine -match 'ffmpeg version (\S+)') { $lv = $Matches[1] } else { $lv = 'inconnue' }
Write-Ok "Version installee : $lv"
$rv = ''
try {
    $rv = Get-WebText 'https://www.gyan.dev/ffmpeg/builds/release-version'
} catch {
    $rv = ''
}
if (-not $rv) {
    Write-Ok 'Impossible de verifier la derniere version en ligne. FFmpeg conserve.'
} else {
    Write-Ok "Derniere version  : $rv"
    if ($lv -like "*$rv*") {
        Write-Ok 'FFmpeg est a jour.'
    } else {
        Write-Ok 'Mise a jour de FFmpeg...'
        try {
            $zip = Join-Path $Root 'ffmpeg.zip'
            $tmpDir = Join-Path $Root 'ffmpeg_tmp'
            Download-File 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip' $zip
            if (Test-Path -LiteralPath $tmpDir) { Remove-Item -LiteralPath $tmpDir -Recurse -Force }
            Expand-Archive -Path $zip -DestinationPath $tmpDir -Force
            $ff = Get-ChildItem -LiteralPath $tmpDir -Recurse -Filter 'ffmpeg.exe' | Select-Object -First 1
            $fp = Get-ChildItem -LiteralPath $tmpDir -Recurse -Filter 'ffprobe.exe' | Select-Object -First 1
            if (-not $ff -or -not $fp) { throw 'ffmpeg.exe / ffprobe.exe introuvables dans le zip' }
            Copy-Item -LiteralPath $ff.FullName -Destination $ffmpeg -Force
            Copy-Item -LiteralPath $fp.FullName -Destination $ffprobe -Force
            Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
            $after = Get-ToolVersion $ffmpeg @('-version')
            Write-Ok ("FFmpeg mis a jour : " + $(if ($after -match 'ffmpeg version (\S+)') { $Matches[1] } else { '?' }))
        } catch {
            Write-Err $_.Exception.Message
        }
    }
}

Write-Host ''
Write-Host '============================================================'
if ($failed) {
    Write-Host '   Mise a jour INCOMPLETE. Relance update.bat.'
    Write-Host '============================================================'
    exit 1
}
Write-Host '   Mise a jour terminee.'
Write-Host '============================================================'
exit 0
