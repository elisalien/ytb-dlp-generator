@echo off
setlocal
cd /d "%~dp0"
chcp 65001 >nul
set "PATH=%~dp0bin;%~dp0;%PATH%"
echo/
echo ============================================================
echo   yt-dlp Studio
echo   1. Dans le navigateur: Copier la commande
echo   2. Ici: clic droit = coller, puis Entree
echo   3. NE collez PAS seulement l'URL YouTube
echo   Sortie: dossier Telechargements
echo ============================================================
echo/
