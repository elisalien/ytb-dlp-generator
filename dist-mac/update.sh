#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
DIR="$(pwd)"
export PATH="$DIR/bin:$PATH"

echo "============================================================"
echo "   yt-dlp Studio - Mise à jour des outils (macOS)"
echo "============================================================"
echo ""
echo "  Vérifie et met à jour, uniquement si nécessaire :"
echo "    - yt-dlp   (auto-mise à jour native)"
echo "    - Deno     (auto-mise à jour native)"
echo "    - FFmpeg   (re-téléchargé seulement si une version plus récente existe)"
echo ""

if [ ! -f bin/yt-dlp ]; then
    echo "  Les outils ne sont pas installés."
    echo "  Lancez d'abord : bash install.sh"
    echo ""
    read -rp "  Appuyez sur Entrée pour fermer..."
    exit 1
fi

echo "[1/3] yt-dlp..."
bin/yt-dlp --update || echo "      (impossible de mettre à jour yt-dlp)"
echo ""

echo "[2/3] Deno..."
bin/deno upgrade || echo "      (impossible de mettre à jour Deno)"
echo ""

echo "[3/3] FFmpeg..."
LOCAL=$(bin/ffmpeg -version 2>/dev/null | head -1 | awk '{print $3}')
REMOTE=$(curl -fsSL --proto '=https' --tlsv1.2 "https://evermeet.cx/ffmpeg/info/ffmpeg/release" 2>/dev/null \
    | sed -n 's/.*"version"[: ]*"\([^"]*\)".*/\1/p' | head -1)
echo "      Version installée : ${LOCAL:-inconnue}"

if [ -z "$REMOTE" ]; then
    echo "      Impossible de vérifier la dernière version en ligne. FFmpeg conservé."
    echo "      (Relancez install.sh pour forcer un re-téléchargement.)"
elif [ -n "$LOCAL" ] && [[ "$LOCAL" == *"$REMOTE"* ]]; then
    echo "      Dernière version  : $REMOTE"
    echo "      FFmpeg est à jour."
else
    echo "      Dernière version  : $REMOTE"
    echo "      Mise à jour de FFmpeg..."
    curl -fL --proto '=https' --tlsv1.2 "https://evermeet.cx/ffmpeg/getrelease/ffmpeg/zip" -o ffmpeg.zip
    unzip -oq ffmpeg.zip -d ffmpeg_tmp
    cp ffmpeg_tmp/ffmpeg bin/ffmpeg
    chmod +x bin/ffmpeg
    rm -rf ffmpeg.zip ffmpeg_tmp
    curl -fL --proto '=https' --tlsv1.2 "https://evermeet.cx/ffmpeg/getrelease/ffprobe/zip" -o ffprobe.zip
    unzip -oq ffprobe.zip -d ffprobe_tmp
    cp ffprobe_tmp/ffprobe bin/ffprobe
    chmod +x bin/ffprobe
    rm -rf ffprobe.zip ffprobe_tmp
    echo "      FFmpeg mis à jour."
fi
echo ""

echo "============================================================"
echo "   Mise à jour terminée."
echo "============================================================"
echo ""
read -rp "  Appuyez sur Entrée pour fermer..."
