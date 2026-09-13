#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
DIR="$(pwd)"
export PATH="$DIR/bin:$PATH"
ARCH=$(uname -m)

echo "============================================================"
echo "   yt-dlp Studio - Mise à jour des outils (Linux)"
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
REMOTE=$(curl -fsSL --proto '=https' --tlsv1.2 "https://johnvansickle.com/ffmpeg/release-readme.txt" 2>/dev/null \
    | grep -iE 'version' | head -1 | grep -oE '[0-9]+(\.[0-9]+)+' | head -1)
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
    if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
        FFMPEG_URL="https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-arm64-static.tar.xz"
    else
        FFMPEG_URL="https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz"
    fi
    curl -fL --proto '=https' --tlsv1.2 "$FFMPEG_URL" -o ffmpeg.tar.xz
    mkdir -p ffmpeg_tmp
    tar -xf ffmpeg.tar.xz -C ffmpeg_tmp
    FF=$(find ffmpeg_tmp -name ffmpeg  -type f -print -quit)
    FP=$(find ffmpeg_tmp -name ffprobe -type f -print -quit)
    [ -n "$FF" ] && cp "$FF" bin/ffmpeg
    [ -n "$FP" ] && cp "$FP" bin/ffprobe
    chmod +x bin/ffmpeg bin/ffprobe
    rm -rf ffmpeg.tar.xz ffmpeg_tmp
    echo "      FFmpeg mis à jour."
fi
echo ""

echo "============================================================"
echo "   Mise à jour terminée."
echo "============================================================"
echo ""
read -rp "  Appuyez sur Entrée pour fermer..."
