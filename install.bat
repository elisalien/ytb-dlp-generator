@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"

echo ============================================================
echo    yt-dlp 4K - Installation des dependances
echo ============================================================
echo.
echo        *      .             .          *       .
echo            .           _____           .
echo     .            _.--""     ""--._         *
echo          *     .'   o   o   o     '.      .
echo        _.----._/_______________________\_.----._
echo       '--..__________________________________..--'
echo            *    \^|   \^|   \^|   \^|   \^|   /      .
echo         .        \^|    \^|   \^|   \^|    /     *
echo      *       .     '.   made with love   .'      .
echo            .          by elisalien - a Lucien
echo        *       .            *          .       *
echo.
echo  Ce script telecharge depuis les sites officiels :
echo    - yt-dlp   (telechargeur video)
echo    - FFmpeg   (fusion video/audio, conversion MP3/HAP)
echo    - Deno     (moteur JavaScript requis par YouTube)
echo.
echo  Tout est installe dans le sous-dossier "bin".
echo  Une connexion internet est requise.
echo.
pause
echo.

if not exist "bin" mkdir "bin"

set "PS=powershell -NoProfile -ExecutionPolicy Bypass -Command"
set "TLS=[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;$ProgressPreference='SilentlyContinue';"

echo [1/3] Telechargement de yt-dlp...
%PS% "%TLS% Invoke-WebRequest -Uri 'https://github.com/yt-dlp/yt-dlp-nightly-builds/releases/latest/download/yt-dlp.exe' -OutFile 'bin\yt-dlp.exe'"
if errorlevel 1 goto :error

echo [2/3] Telechargement de FFmpeg (peut prendre une minute)...
%PS% "%TLS% Invoke-WebRequest -Uri 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip' -OutFile 'ffmpeg.zip'"
if errorlevel 1 goto :error
echo       Extraction de FFmpeg...
%PS% "Expand-Archive -Path 'ffmpeg.zip' -DestinationPath 'ffmpeg_tmp' -Force"
%PS% "Get-ChildItem -Path 'ffmpeg_tmp' -Recurse -Filter 'ffmpeg.exe'  | Select-Object -First 1 | %% { Copy-Item $_.FullName 'bin\ffmpeg.exe'  -Force }"
%PS% "Get-ChildItem -Path 'ffmpeg_tmp' -Recurse -Filter 'ffprobe.exe' | Select-Object -First 1 | %% { Copy-Item $_.FullName 'bin\ffprobe.exe' -Force }"
del "ffmpeg.zip" >nul 2>&1
rmdir /s /q "ffmpeg_tmp" >nul 2>&1

echo [3/3] Telechargement de Deno (moteur JavaScript pour YouTube)...
%PS% "%TLS% Invoke-WebRequest -Uri 'https://github.com/denoland/deno/releases/latest/download/deno-x86_64-pc-windows-msvc.zip' -OutFile 'deno.zip'"
if errorlevel 1 goto :error
echo       Extraction de Deno...
%PS% "Expand-Archive -Path 'deno.zip' -DestinationPath 'bin' -Force"
del "deno.zip" >nul 2>&1

echo.
if not exist "bin\yt-dlp.exe" goto :error
if not exist "bin\ffmpeg.exe" goto :error
if not exist "bin\deno.exe"   goto :error

echo ============================================================
echo    Installation terminee avec succes !
echo    Double-cliquez maintenant sur  launch.bat
echo ============================================================
echo.
pause
exit /b 0

:error
echo.
echo  *** ERREUR pendant le telechargement ou l'extraction. ***
echo  Verifiez votre connexion internet puis relancez install.bat
echo.
pause
exit /b 1
