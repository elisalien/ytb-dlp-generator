#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

trap 'echo ""; echo " *** ERREUR pendant le téléchargement ou l'\''extraction. ***"; echo " Vérifiez votre connexion internet puis relancez : bash install.sh"; exit 1' ERR

ARCH=$(uname -m)

echo "============================================================"
echo "   yt-dlp 4K - Installation des dépendances (Linux)"
echo "============================================================"
echo ""
echo "       *      .             .          *       ."
echo "           .           _____           ."
echo "    .            _.--\"\"     \"\"--._         *"
echo "         *     .'   o   o   o     '.      ."
echo "       _.----._/_______________________\_.----._"
echo "      '--..__________________________________..--'"
echo "           *    \|   \|   \|   \|   \|   /      ."
echo "        .        \|    \|   \|   \|    /     *"
echo "     *       .     '.   made with love   .'      ."
echo "           .          by elisalien - a Lucien"
echo "       *       .            *          .       *"
echo ""
echo "  Ce script télécharge depuis les sites officiels :"
echo "    - yt-dlp   (téléchargeur vidéo)"
echo "    - FFmpeg   (fusion vidéo/audio, conversion MP3/HAP)"
echo "    - Deno     (moteur JavaScript requis par YouTube)"
echo ""
echo "  Tout est installé dans le sous-dossier \"bin\"."
echo "  Architecture détectée : $ARCH"
echo "  Une connexion internet est requise."
echo ""
read -rp "  Appuyez sur Entrée pour continuer..."
echo ""

mkdir -p bin

echo "[1/3] Téléchargement de yt-dlp..."
curl -fsSL --proto '=https' --tlsv1.2 "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux" -o bin/yt-dlp
chmod +x bin/yt-dlp
echo "      OK"
echo ""

echo "[2/3] Téléchargement de FFmpeg (peut prendre une minute)..."
if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    FFMPEG_URL="https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-arm64-static.tar.xz"
else
    FFMPEG_URL="https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz"
fi
curl -fL --proto '=https' --tlsv1.2 "$FFMPEG_URL" -o ffmpeg.tar.xz
mkdir -p ffmpeg_tmp
tar -xf ffmpeg.tar.xz -C ffmpeg_tmp
FF=$(find ffmpeg_tmp -name "ffmpeg"  -type f -print -quit)
FP=$(find ffmpeg_tmp -name "ffprobe" -type f -print -quit)
[ -n "$FF" ] && cp "$FF" bin/ffmpeg
[ -n "$FP" ] && cp "$FP" bin/ffprobe
chmod +x bin/ffmpeg bin/ffprobe
rm -rf ffmpeg.tar.xz ffmpeg_tmp
echo "      OK"
echo ""

echo "[3/3] Téléchargement de Deno (moteur JavaScript pour YouTube)..."
if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    DENO_URL="https://github.com/denoland/deno/releases/latest/download/deno-aarch64-unknown-linux-gnu.zip"
else
    DENO_URL="https://github.com/denoland/deno/releases/latest/download/deno-x86_64-unknown-linux-gnu.zip"
fi
curl -fsSL --proto '=https' --tlsv1.2 "$DENO_URL" -o deno.zip
unzip -oq deno.zip -d bin
chmod +x bin/deno
rm -f deno.zip
echo "      OK"
echo ""

[ -f "bin/yt-dlp" ] || { echo "Erreur : bin/yt-dlp manquant"; exit 1; }
[ -f "bin/ffmpeg" ] || { echo "Erreur : bin/ffmpeg manquant"; exit 1; }
[ -f "bin/deno"   ] || { echo "Erreur : bin/deno manquant";   exit 1; }

echo "============================================================"
echo "   Installation terminée avec succès !"
echo "   Lancez ensuite l'application avec : bash launch.sh"
echo "============================================================"
echo ""
read -rp "  Appuyez sur Entrée pour fermer..."
