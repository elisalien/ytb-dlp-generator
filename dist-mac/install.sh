#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

trap 'echo ""; echo " *** ERREUR pendant le téléchargement ou l'\''extraction. ***"; echo " Vérifiez votre connexion internet puis relancez : bash install.sh"; exit 1' ERR

echo "============================================================"
echo "   yt-dlp 4K - Installation des dépendances (macOS)"
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
echo "  Une connexion internet est requise."
echo ""
read -rp "  Appuyez sur Entrée pour continuer..."
echo ""

mkdir -p bin

echo "[1/3] Téléchargement de yt-dlp..."
curl -fsSL --proto '=https' --tlsv1.2 "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos" -o bin/yt-dlp
chmod +x bin/yt-dlp
echo "      OK"
echo ""

echo "[2/3] Téléchargement de FFmpeg (peut prendre une minute)..."
curl -fL --proto '=https' --tlsv1.2 "https://evermeet.cx/ffmpeg/getrelease/ffmpeg/zip" -o ffmpeg.zip
unzip -oq ffmpeg.zip -d ffmpeg_tmp
cp ffmpeg_tmp/ffmpeg bin/ffmpeg
chmod +x bin/ffmpeg
rm -rf ffmpeg.zip ffmpeg_tmp

echo "      Téléchargement de ffprobe..."
curl -fL --proto '=https' --tlsv1.2 "https://evermeet.cx/ffmpeg/getrelease/ffprobe/zip" -o ffprobe.zip
unzip -oq ffprobe.zip -d ffprobe_tmp
cp ffprobe_tmp/ffprobe bin/ffprobe
chmod +x bin/ffprobe
rm -rf ffprobe.zip ffprobe_tmp
echo "      OK"
echo ""

echo "[3/3] Téléchargement de Deno (moteur JavaScript pour YouTube)..."
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    DENO_URL="https://github.com/denoland/deno/releases/latest/download/deno-aarch64-apple-darwin.zip"
else
    DENO_URL="https://github.com/denoland/deno/releases/latest/download/deno-x86_64-apple-darwin.zip"
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
