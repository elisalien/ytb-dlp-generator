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
xdg-open "$DIR/index.html" 2>/dev/null &

# Crée un script temporaire pour la fenêtre Terminal
TMPSCRIPT=$(mktemp /tmp/yt-dlp-XXXXXX.sh)
cat > "$TMPSCRIPT" << EOF
#!/usr/bin/env bash
export PATH="$DIR/bin:\$PATH"
cd "$DIR"
echo ""
echo "=== Collez la commande copiée (Ctrl+Shift+V) puis Entrée ==="
echo "=== Les vidéos seront enregistrées dans ce dossier. ==="
echo ""
exec bash
EOF
chmod +x "$TMPSCRIPT"

# Détecte et ouvre un émulateur de terminal
for TERM_APP in gnome-terminal konsole xfce4-terminal lxterminal mate-terminal tilix xterm; do
    if command -v "$TERM_APP" &>/dev/null; then
        case "$TERM_APP" in
            gnome-terminal) gnome-terminal -- bash "$TMPSCRIPT" & ;;
            konsole)        konsole -e bash "$TMPSCRIPT" & ;;
            xterm)          xterm -e bash "$TMPSCRIPT" & ;;
            *)              "$TERM_APP" -e "bash '$TMPSCRIPT'" & ;;
        esac
        exit 0
    fi
done

echo ""
echo "  Aucun émulateur de terminal trouvé."
echo "  Ouvrez un terminal manuellement et collez vos commandes ici."
echo ""
