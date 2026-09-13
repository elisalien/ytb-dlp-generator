# yt-dlp Studio

Téléchargeur vidéo 4K / 8K et convertisseur local, piloté depuis le navigateur.
MP4 compatible, MP3, export HAP pour Resolume, extraction de frames — sans ligne de commande.

---

## Fonctionnalités (Windows)

- **Téléchargement direct** — collez ou glissez vos liens, cliquez sur Télécharger : la progression s'affiche dans la file d'attente
- **Formats** — Compatible (H.264 · AAC · MP4), Ultime, 4K, 2K, Full HD, MP3, Frames PNG
- **VJ** — HAP / HAP Q (`.mov`) lus nativement par Resolume et Alley
- **Onglet Convertir** — fichiers locaux vers MP4 compatible, MP4 HQ, HAP, HAP Q ou MP3, avec largeur maximale
- **Rangement automatique** — dossier par playlist, sous-dossier « Lot » pour plusieurs liens
- **Favori navigateur** — envoie la page vidéo courante vers Studio en un clic
- **Portable** — yt-dlp, FFmpeg et Deno dans `bin/`, mis à jour automatiquement au lancement

---

## Installation

**Windows** — téléchargez `yt-dlp-4k-windows.zip` depuis la [dernière release](https://github.com/elisalien/ytb-dlp-studio/releases/latest), décompressez, puis :

1. Lancez `install.bat` (SmartScreen : *Informations complémentaires* → *Exécuter quand même*)
2. Facultatif : `create-shortcut.bat` pour un raccourci sur le Bureau

**macOS / Linux** — dans `dist-mac/` ou `dist-linux/` (générateur de commandes, sans serveur) :

```bash
chmod +x install.sh launch.sh update.sh
bash install.sh
```

---

## Utilisation (Windows)

1. Lancez `launch.bat` : l'interface s'ouvre dans le navigateur (Firefox en priorité)
2. **Télécharger** — liens, format, dossier de destination → Télécharger (Ctrl + Entrée)
3. **Convertir** — fichier source, préréglage → Convertir ; le résultat est créé à côté de la source

Une fenêtre « yt-dlp Studio - serveur » reste réduite dans la barre des tâches : c'est elle qui travaille.
Erreur 403 : laissez « Cookies du navigateur » activé avec Firefox connecté à YouTube.

---

## Mise à jour

Automatique au lancement (au plus toutes les 12 h). Pour forcer : `update.bat` / `update.sh`.
Seul ce qui est périmé est retéléchargé. FFmpeg utilise la build *full* de gyan.dev, la seule qui contient l'encodeur HAP.

---

## Structure

```
server.ps1        # serveur local : file d'attente yt-dlp / ffmpeg, API de la page
index.html        # interface
launch.bat        # démarre le serveur et ouvre l'interface
install.bat       # première installation (appelle update.ps1)
update.ps1/.bat   # installe ou met à jour yt-dlp, Deno, FFmpeg dans bin/
terminal.bat      # mode manuel : terminal prêt à coller une commande
extract-frames.bat, create-shortcut.*, assets/
dist-mac/, dist-linux/   # versions macOS et Linux
```

---

## Sécurité

- Le serveur écoute uniquement sur `127.0.0.1` et exige un jeton aléatoire injecté dans la page ; l'en-tête `Host` est vérifié (anti DNS rebinding)
- La page n'envoie jamais de ligne de commande : le serveur construit les arguments à partir d'options en liste blanche, sans shell
- Les titres de vidéos sont affichés via `textContent` uniquement (pas de XSS)
- Binaires téléchargés en HTTPS depuis les sites officiels

Usage personnel et légal uniquement. Respectez le droit d'auteur.

---

## Crédits

| Outil  | Licence   | Lien |
|--------|-----------|------|
| yt-dlp | Unlicense | https://github.com/yt-dlp/yt-dlp |
| FFmpeg | GPL/LGPL  | https://ffmpeg.org |
| Deno   | MIT       | https://deno.com |

Non redistribués : téléchargés à l'installation.

---

made with ♥ by **elisalien** — pour Lucien
