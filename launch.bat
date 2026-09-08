@echo off
chcp 65001 >nul
cd /d "%~dp0"

REM Ajoute bin + racine au PATH (yt-dlp, ffmpeg, extract-frames.bat)
set "PATH=%~dp0bin;%~dp0;%PATH%"

if not exist "bin\yt-dlp.exe" goto :missing
if not exist "bin\ffmpeg.exe"  goto :missing

REM Interface dans un vrai navigateur (script PS dedie = quoting fiable)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0open-ui.ps1"

REM Terminal pret a coller la commande (/k garde la fenetre ouverte apres le setup)
start "yt-dlp Studio" cmd /k "%~dp0terminal.bat"

exit /b 0

:missing
echo.
echo  Les dependances ne sont pas installees.
echo  Double-cliquez d'abord sur  install.bat
echo.
pause
exit /b 1
