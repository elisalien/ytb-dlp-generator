@echo off
chcp 65001 >nul
cd /d "%~dp0"

REM Ajoute bin + racine au PATH (yt-dlp, ffmpeg, extract-frames.bat)
set "PATH=%~dp0bin;%~dp0;%PATH%"

if not exist "bin\yt-dlp.exe" goto :missing
if not exist "bin\ffmpeg.exe"  goto :missing

REM Serveur local (fenetre reduite) : ouvre l'interface dans le navigateur et
REM lance les telechargements directement. S'il tourne deja, rouvre juste l'interface.
REM Mode manuel (copier/coller une commande) : terminal.bat
start "yt-dlp Studio" /min powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0server.ps1"

exit /b 0

:missing
echo.
echo  Les dependances ne sont pas installees.
echo  Double-cliquez d'abord sur  install.bat
echo.
pause
exit /b 1
