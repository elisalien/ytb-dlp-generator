@echo off
cd /d "%~dp0"

if not exist "bin\yt-dlp.exe" goto :missing
if not exist "bin\ffmpeg.exe" goto :missing
if not exist "bin\deno.exe"   goto :missing

REM Serveur local en fenetre reduite : ouvre l'interface dans le navigateur et
REM lance les telechargements. S'il tourne deja, rouvre simplement l'interface.
REM Mode manuel (copier/coller une commande) : terminal.bat
start "yt-dlp Studio" /min powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0server.ps1"
exit /b 0

:missing
echo.
echo  Les outils ne sont pas installes.
echo  Double-cliquez d'abord sur  install.bat
echo.
pause
exit /b 1
