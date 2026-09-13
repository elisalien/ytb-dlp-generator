@echo off
setlocal
cd /d "%~dp0"
chcp 65001 >nul
set "PATH=%~dp0bin;%~dp0;%PATH%"

REM Verification auto des outils (yt-dlp nightly / Deno / FFmpeg), 1x toutes les 12h max.
REM Pour forcer une verif complete : double-clic sur update.bat
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0update.ps1" -Auto

echo/
echo ============================================================
echo   yt-dlp Studio - mode manuel
echo   (launch.bat telecharge directement, sans ce terminal)
echo   1. Options avancees: Commande equivalente, Copier
echo   2. Ici: clic droit = coller, puis Entree
echo   3. NE collez PAS seulement l'URL YouTube
echo   Sortie: dossier Telechargements
echo ============================================================
echo/
