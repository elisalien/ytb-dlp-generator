# yt-dlp Studio

Interface locale pour générer des commandes **yt-dlp** et **ffmpeg**.  
Téléchargement 4K/8K, MP3, export HAP, conversion locale — sans serveur.

---

## Fonctionnalités

- **Sorties compatibles** — H.264 · AAC · MP4 pour une lecture fiable (VLC, mobile, TV, montage)
- **Téléchargement multi-URL** — une URL par ligne, playlists supportées
- **Qualités** — Ultime, 4K, 2K, Full HD
- **Audio** — extraction MP3
- **VJ** — export HAP / HAP Q (`.mov`) pour Resolume
- **Onglet ffmpeg** — conversion locale : MP4, MP3, HAP
- **Portable** — yt-dlp, FFmpeg et Deno dans `bin/`, rien d’installé ailleurs

---

## Installation

**Windows** — une seule fois :

1. Téléchargez le dépôt et ouvrez `dist/`
2. Lancez `install.bat`  
   (SmartScreen : *Informations complémentaires* → *Exécuter quand même*)

**macOS / Linux** — dans `dist-mac/` ou `dist-linux/` :

```bash
chmod +x install.sh launch.sh update.sh
bash install.sh
```

---

## Utilisation

1. Lancez `launch.bat` (Windows) ou `bash launch.sh` (macOS / Linux)
2. **Télécharger** — collez les URLs, choisissez un profil, copiez la commande
3. **ffmpeg commandes** — indiquez un fichier source, choisissez un preset, copiez la commande
4. Collez dans le Terminal, puis Entrée

Les téléchargements vont dans `Téléchargements/`.  
Laissez le champ FFmpeg vide : il est déjà inclus.

---

## Mise à jour

`update.bat` / `update.sh` met à jour uniquement ce qui est périmé (yt-dlp, Deno, FFmpeg).  
Pour tout réinstaller : `install.bat` / `install.sh`.

---

## Structure

```
dist/          # Windows
dist-mac/      # macOS
dist-linux/    # Linux
```

Chaque dossier contient l’interface, les scripts d’install / lancement / mise à jour.

---

## Sécurité

- Interface locale (`file://`), aucun serveur
- Entrées utilisateur nettoyées contre l’injection shell
- Binaires téléchargés en HTTPS depuis les sites officiels

Usage personnel et légal uniquement. Respectez le droit d’auteur.

---

## Crédits

| Outil  | Licence   | Lien |
|--------|-----------|------|
| yt-dlp | Unlicense | https://github.com/yt-dlp/yt-dlp |
| FFmpeg | GPL/LGPL  | https://ffmpeg.org |
| Deno   | MIT       | https://deno.com |

Non redistribués : téléchargés à l’installation.

---

made with ♥ by **elisalien** — pour Lucien
