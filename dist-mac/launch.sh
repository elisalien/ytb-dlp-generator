#!/usr/bin/env bash
cd "$(dirname "$0")"

DIR="$(pwd)"
export PATH="$DIR/bin:$PATH"

if [ ! -f "bin/yt-dlp" ]; then
    echo ""
    echo "  Les dépendances ne sont pas installées."
    echo "  Exécutez d'abord : bash install.sh"
    echo ""
    read -rp "  Appuyez sur Entrée pour fermer..."
    exit 1
fi

# Ouvre l'interface dans le navigateur par défaut
open "$DIR/index.html"

# Crée un script temporaire pour la fenêtre Terminal
TMPSCRIPT=$(mktemp /tmp/yt-dlp-XXXXXX.sh)
cat > "$TMPSCRIPT" << EOF
#!/usr/bin/env bash
export PATH="$DIR/bin:\$PATH"
cd "$DIR"
echo ""
echo "=== Collez la commande copiée (Cmd+V ou clic droit) puis Entrée ==="
echo "=== Les vidéos seront enregistrées dans ce dossier. ==="
echo ""
EOF
chmod +x "$TMPSCRIPT"

# Ouvre une nouvelle fenêtre Terminal
osascript \
    -e "tell application \"Terminal\" to do script \"bash '$TMPSCRIPT'\"" \
    -e "tell application \"Terminal\" to activate"
