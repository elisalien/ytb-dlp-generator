@echo off
REM Extrait toutes les frames d'une video dans le meme dossier.
REM Appelle par yt-dlp --exec apres telechargement.
setlocal
set "VIDEO=%~f1"
if "%VIDEO%"=="" exit /b 1
if not exist "%VIDEO%" exit /b 1
set "DIR=%~dp1"
ffmpeg -hide_banner -y -i "%VIDEO%" "%DIR%frame_%%05d.png"
exit /b %ERRORLEVEL%
