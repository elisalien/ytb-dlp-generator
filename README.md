# 🎬 yt-dlp Studio

> Interface graphique minimaliste pour générer des commandes **yt-dlp** : téléchargement vidéo haute qualité 4K / 8K, fusion audio/vidéo, MP3, export VJ HAP.

Aucune ligne de commande à connaître : on colle ses liens, on sélectionne un profil, on copie la commande, on la colle dans le terminal fourni. Tout est portable et reste dans le dossier de l'outil.

---

## ✨ Fonctionnalités

- 🛡️ **Profils vidéo vraiment compatibles** — les presets standards sortent maintenant en **H.264 · AAC · MP4** avec ré-encodage de sécurité : lecture plus fiable dans VLC, QuickTime, TV, mobile et logiciels de montage.
- 📥 **Téléchargement multi-URLs** — une ou plusieurs vidéos d'un coup (une URL par ligne).
- 🌟 **Qualité au choix** — Ultime (4K/8K sans limite), 4K (2160p), 2K (1440p), Full HD (1080p).
- 🎵 **Audio seul** — extraction MP3 en qualité maximale.
- 🎛️ **Export VJ** — ré-encodage en codec **HAP** / **HAP Q** (`.mov`) lu nativement par Resolume Arena/Avenue et Alley.
- 🎞️ **Onglet "ffmpeg commandes"** — conversion de fichiers locaux via des commandes prêtes à coller : MP4 universel, MP4 HQ, MP3, HAP, HAP Q.
- 📚 **Playlists** — téléchargement complet avec sous-dossier par playlist.
- 📁 **Rangement automatique** — les vidéos atterrissent dans `Téléchargements/`.
- 🔌 **100 % portable** — yt-dlp, FFmpeg et Deno sont téléchargés dans un sous-dossier `bin/` ; rien n'est installé ailleurs sur le PC.

---

## 📦 Prérequis

- **Windows** 10 / 11
- Une **connexion internet** (uniquement pour la première installation)

Aucune installation manuelle de yt-dlp, FFmpeg ou Deno : le script s'en charge.

---

## 🚀 Installation

> À faire **une seule fois**.

1. Téléchargez ce dépôt (bouton **Code → Download ZIP**) et décompressez-le, ou clonez-le :
   ```bash
   git clone https://github.com/elisalien/ytb-dlp-generator.git
   ```
2. Ouvrez le dossier `dist/`.
3. Double-cliquez sur **`install.bat`**.
   - Il télécharge automatiquement depuis les **sites officiels** : yt-dlp, FFmpeg et Deno, dans le sous-dossier `bin/`.
   - Si Windows SmartScreen apparaît : *Informations complémentaires* → *Exécuter quand même*.

---

## 🔄 Mise à jour des outils

Lancez **`update.bat`** (Windows) ou **`bash update.sh`** (macOS / Linux) quand vous le souhaitez.
Le script **vérifie d'abord si des mises à jour sont disponibles** et ne télécharge que le nécessaire :

- **yt-dlp** — auto-mise à jour native (`yt-dlp --update`). C'est l'outil à actualiser le plus souvent : YouTube change régulièrement et casse les anciennes versions.
- **Deno** — auto-mise à jour native (`deno upgrade`).
- **FFmpeg** — la version installée est comparée à la dernière version officielle ; le re-téléchargement n'a lieu **que si une version plus récente existe**.

> `install.bat` / `install.sh` (re)téléchargent tout de zéro ; `update.bat` / `update.sh` ne touchent qu'à ce qui est périmé.

---

## 🕹️ Utilisation

1. Double-cliquez sur **`launch.bat`**.
   - L'interface s'ouvre directement dans votre navigateur.
   - Une fenêtre « Terminal » noire s'ouvre aussi : **c'est là que les vidéos se téléchargent** (ne la fermez pas).
2. Dans l'interface, onglet **⬇️ Télécharger** :
   - Collez vos liens YouTube (un par ligne).
   - Choisissez un **profil** (par défaut : *Compatibilité maximale*) et, si besoin, cochez **playlist**.
   - Cliquez sur **Copier la commande**.
   - *(Le champ **FFmpeg**, dans « Options avancées », reste vide : il est déjà inclus.)*
3. Pour convertir un fichier local, basculez sur l'onglet **🎞️ ffmpeg commandes** :
   - Renseignez le **fichier source**.
   - Choisissez un **preset** de conversion (MP4 compatible, MP4 HQ, MP3, HAP, HAP Q).
   - Ajustez éventuellement le **fichier de sortie** et le redimensionnement.
   - Cliquez sur **Copier la commande**.
4. Cliquez dans la fenêtre « Terminal », faites un **clic droit** (= coller), puis **Entrée**.
5. Les téléchargements sont enregistrés dans `dist/Téléchargements/`. Les conversions FFmpeg utilisent le chemin de sortie indiqué dans la commande.

---

## 🛠️ Comment ça marche

```
dist/
├── install.bat     # Télécharge yt-dlp + FFmpeg + Deno dans bin/
├── update.bat      # Vérifie et met à jour les outils (seulement si besoin)
├── launch.bat      # Ouvre l'interface + un terminal prêt à l'emploi
├── index.html      # L'interface : génère la commande yt-dlp
└── bin/            # Outils téléchargés (non versionnés)
```

*(macOS / Linux : mêmes fichiers en `.sh` dans `dist-mac/` et `dist-linux/`.)*

- `index.html` **ne télécharge rien lui-même** : c'est un générateur de commande. Il construit la ligne `yt-dlp …` adaptée à vos choix.
- La page s'ouvre directement en local (`file://`) — **aucun serveur requis**. Le bouton « Copier » utilise l'API presse-papier moderne quand elle est disponible, avec un repli `execCommand` qui fonctionne en double-clic.
- Le téléchargement réel est fait par `yt-dlp` + `FFmpeg` dans le terminal, sur **votre** machine.
- **Deno** est présent dans `bin/` uniquement comme **moteur JavaScript** : yt-dlp l'utilise pour extraire les formats YouTube haute qualité (sans lui, YouTube est dégradé à ~1080p). Il **ne tourne pas en serveur** — yt-dlp le lance ponctuellement lui-même, car `launch.bat` ajoute `bin/` au PATH.

---

## 🔐 Sécurité

- **Aucun serveur, aucun port ouvert** — l'interface tourne en local (`file://`) ; rien n'écoute sur le réseau.
- **Anti-injection shell renforcé** — la commande générée est destinée à être collée dans un terminal. À l'intérieur de guillemets doubles, un shell Unix (bash/zsh) interprète **encore** `$(…)`, les backticks `` ` `` et `$VAR` : retirer seulement les guillemets **ne suffit pas**. L'interface neutralise donc, selon le contexte, **tous** les métacaractères réellement dangereux :
  - **URLs** : validation `http(s)` stricte, puis suppression des espaces, guillemets (`"` `'`), backtick, `$`, `\` et `< > |` — aucun n'est légitime dans une URL bien formée, donc les vrais liens ne sont pas altérés (les `&`, `?`, `%` des URL YouTube sont conservés).
  - **Chemin FFmpeg** : suppression de `$`, backtick, guillemets et d'un `\` final (qui pourrait échapper le guillemet fermant).
  - Aucune donnée utilisateur n'est insérée en HTML via `innerHTML` (uniquement `textContent`) → pas de XSS.
- **Téléchargements officiels en HTTPS strict** — les binaires proviennent uniquement des dépôts/sites officiels. Windows force TLS 1.2 ; macOS / Linux forcent `--proto '=https' --tlsv1.2` sur chaque `curl`, ce qui **interdit toute redirection vers du HTTP non chiffré** (pas de downgrade possible).
- **Mises à jour vérifiées** — `update` s'appuie sur les mécanismes signés de yt-dlp (`--update`) et Deno (`upgrade`), et ne re-télécharge FFmpeg que si la version distante diffère.

---

## ⚠️ Avertissement

Cet outil est destiné à un usage **personnel et légal**. Respectez les conditions d'utilisation des plateformes et le droit d'auteur. Vous êtes responsable des contenus que vous téléchargez.

---

## 📜 Crédits & licences

Cet outil télécharge et utilise des logiciels tiers gratuits (**non redistribués** ici) :

| Outil   | Rôle                                   | Licence    | Lien |
|---------|----------------------------------------|------------|------|
| yt-dlp  | Téléchargeur vidéo                      | Unlicense  | <https://github.com/yt-dlp/yt-dlp> |
| FFmpeg  | Fusion audio/vidéo, conversion MP3/HAP | GPL/LGPL   | <https://ffmpeg.org> |
| Deno    | Moteur JavaScript pour l'extraction YouTube | MIT     | <https://deno.com> |

---

<p align="center">made with ♥ by <b>elisalien</b> — pour Lucien</p>
