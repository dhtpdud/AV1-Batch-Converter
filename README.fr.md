# convert-av1

[English](README.md) | [한국어](README.ko.md) | [简体中文](README.zh-CN.md) | [日本語](README.ja.md) | [Español](README.es.md) | **Français** | [Deutsch](README.de.md) | [Português](README.pt-BR.md) | [Русский](README.ru.md) | [العربية](README.ar.md) | [हिन्दी](README.hi.md)

Script batch Windows qui convertit en AV1 toutes les vidéos d'un dossier et de ses sous-dossiers.
Il utilise d'abord NVIDIA NVENC et passe automatiquement à un autre encodeur si NVENC n'est pas disponible.

> [!WARNING]
> **Les pistes de sous-titres ne sont pas conservées dans le résultat.** En mode Y (suppression des originaux), les sous-titres de l'original disparaissent avec lui et ne peuvent pas être récupérés.
> Utilisez d'abord le mode N et vérifiez les résultats avant d'utiliser le mode Y. Veuillez d'abord lire les [Limitations](#limitations).

## Résultats attendus

Lorsque vous exécutez le script :

- Il recherche les fichiers mp4, mkv, mov, avi, wmv, flv, webm, m4v, ts, mts, m2ts, mpg et mpeg dans le dossier et ses sous-dossiers.
- Les vidéos déjà en AV1 ne sont pas converties.
- Pour les vidéos de 1 minute ou plus, il encode d'abord 10 secondes prises au milieu. Si la taille estimée dépasse 90% de l'original, la vidéo n'est pas convertie.
- Si le résultat final a la même taille que l'original ou est plus gros, il est écarté et l'original est conservé.
- Si une conversion échoue, l'original n'est pas supprimé.
- La vérification de l'AV1 et l'encodage s'exécutent en même temps. L'encodage traite un fichier à la fois.
- Une nouvelle exécution ignore les fichiers déjà traités : vous pouvez donc reprendre après un arrêt.

**Les vidéos ne deviennent pas toutes plus petites.** Les vidéos déjà bien compressées sont ignorées, et le gain varie d'une vidéo à l'autre.

### Quelle réduction de taille

**De 0% (non convertie, original conservé) à un maximum mesuré de 96%.** Les fichiers ne deviennent jamais plus gros, car un résultat de même taille ou plus gros est écarté.

Ces résultats proviennent de 52 vraies vidéos choisies au hasard sur un même PC, avec les réglages par défaut (NVENC, CQ 30).

| Cas | Taille par rapport à l'original | Gain |
|---|---|---|
| Gain le plus élevé | 4% | 96% |
| Médiane des 41 vidéos converties | 44% | 56% |
| Gain le plus faible parmi les vidéos converties | 89% | 11% |
| Les 11 vidéos ignorées (taille estimée 96-233%) | 100% (original conservé) | 0% |

| Codec source | Échantillon | Converties | Taille des vidéos converties par rapport à l'original |
|---|---|---|---|
| H.264 | 25 | 18 | 4-89% |
| HEVC | 25 | 21 | 15-88% |
| VP9, MPEG-4 | 1 chacun | 2 | 81%, 23% |

Plus le débit de la source est élevé, plus le gain est important. La taille médiane, vidéos ignorées comprises, était de 76% en dessous de 5 Mbps, de 50% à 5-15 Mbps et de 27% à 15-40 Mbps.

Ces chiffres ne sont pas une garantie.

- Chaque vidéo a été comparée sur la piste vidéo uniquement, à partir de 10 secondes prises à chacun des points 25%, 50% et 75%, soit 30 secondes au total. Ce ne sont pas des résultats de conversion de fichiers entiers.
- L'audio est généralement copié tel quel, donc les fichiers réels diminuent moins que ne l'indiquent ces chiffres.
- Seules des vidéos de 1 minute ou plus ont été mesurées, et elles proviennent de la collection d'une seule personne. La plage peut être différente pour d'autres vidéos.
- Seul NVENC a été mesuré. D'autres encodeurs et d'autres valeurs de `CQ` donnent des résultats différents.
- Si l'estimation avant conversion est fausse, un résultat dont le gain est inférieur à 10% peut subsister.

### Emplacement des résultats

| Mode | Enregistré dans | Original |
|---|---|---|
| N (recommandé) | Un dossier `av1\` dans chaque dossier | Conservé |
| Y | À l'emplacement de l'original | **Supprimé définitivement** après une conversion réussie (ne passe pas par la Corbeille) |

L'extension reste celle de l'original. Les exceptions sont mov, m4v, ts, mts, m2ts, mpg et mpeg, qui ne peuvent pas contenir de l'AV1 et sont enregistrés en `.mp4`.

### Ce qui est conservé après la conversion

Ces résultats ont été vérifiés avec des vidéos de test.

| Élément | Résultat |
|---|---|
| Première piste vidéo | Convertie en AV1 |
| Pistes audio (y compris les pistes multiples et les étiquettes de langue) | Conservées. Copiées telles quelles. Lors de l'enregistrement en mp4, les formats incompatibles sont convertis en AAC 192 kbps |
| Chapitres, titre | Conservés |
| 10 bits | Conservé |
| HDR10 (BT.2020, PQ, données de l'écran de mastering) | Conservé (vérifié avec NVENC) |
| Rotation | L'image elle-même est pivotée à l'enregistrement. Le rendu est identique |
| **Pistes de sous-titres** | **Perdues** |
| **Deuxième piste vidéo et suivantes** | **Perdues** |
| **Couleur 4:2:2 et 4:4:4** | **Réduite à 4:2:0** |

## Configuration requise

- Windows 10 ou 11
- `ffmpeg` et `ffprobe` dans le PATH
- Au moins un des encodeurs ci-dessous

| Ordre | Encodeur | Nécessite |
|---|---|---|
| 1 | NVENC (`av1_nvenc`), 2 moteurs | Une carte graphique NVIDIA avec 2 encodeurs AV1, comme la RTX 4070 Ti |
| 2 | NVENC (`av1_nvenc`), 1 moteur | Une carte graphique NVIDIA compatible AV1 (série RTX 40 ou ultérieure) |
| 3 | Intel Quick Sync (`av1_qsv`) | Processeur graphique Intel avec encodage AV1 |
| 4 | AMD AMF (`av1_amf`) | Processeur graphique AMD avec encodage AV1 |
| 5 | CPU (`libsvtav1`, preset 10) | Une version de ffmpeg qui inclut SVT-AV1 |

Au démarrage, le script effectue un véritable encodage de test dans cet ordre et utilise le premier qui fonctionne. L'encodeur utilisé est indiqué sur la ligne `Encoder: ...`.

## Utilisation

1. Téléchargez `convert_av1.bat` depuis [Releases](../../releases/latest).
2. Faites glisser le dossier à convertir sur le fichier bat, ou exécutez le fichier bat et saisissez le chemin du dossier.
3. Vérifiez le dossier cible et choisissez `Y` (supprimer les originaux) ou `N` (conserver les originaux).

La progression de la vérification s'affiche dans le titre de la fenêtre. Vous pouvez lancer plusieurs fenêtres sur différents dossiers en même temps, mais chaque fenêtre sera plus lente.

**Pour arrêter** : fermez la fenêtre. Le fichier `name.part.ext` de la conversion en cours reste en place, supprimez-le donc vous-même.

### Réglages

Modifiez ces valeurs vers le début du fichier bat.

| Valeur | Par défaut | Signification |
|---|---|---|
| `CQ` | 30 | Qualité (0-63). Une valeur plus basse donne une meilleure qualité et des fichiers plus gros. S'applique de la même façon à toutes les vidéos |
| `JOBS` | 8 | Nombre de fichiers à vérifier en même temps pour détecter l'AV1 |
| `MIN_SAVE` | 10 | Ne pas convertir si le gain estimé (%) est inférieur à cette valeur |

## Mesures

Mesuré avec une RTX 4070 Ti, un i7-13700KF, Windows 11 et une version de ffmpeg de 2026-10. Les résultats seront différents dans d'autres environnements.

### Vitesse d'encodage

| Résolution | NVENC, 1 moteur | NVENC, 2 moteurs | CPU SVT-AV1 preset 10 |
|---|---|---|---|
| 8K (7680×3840) | 31 fps | 55 fps | Environ 14 fps |
| 4K | 107 fps | 189 fps | Non mesuré |
| 1080p | 400 fps | 574 fps | Environ 518 fps |

Les mesures CPU ont été effectuées pendant que d'autres conversions tournaient. Encodeurs logiciels comparés en 1080p : SVT-AV1 environ 518 fps, libaom environ 173 fps, rav1e environ 5 fps.

### CQ et taille de fichier

Résultats de la conversion avec NVENC d'un extrait de 20 secondes d'une vidéo HEVC 8K (source 30 Mbps). C'est un exemple de vidéo déjà bien compressée qui grossit avec CQ 30.

| CQ | Débit | SSIM (par rapport à l'original) | Décision |
|---|---|---|---|
| 30 | 53.9 Mbps | 0.9955 | Ignorée car elle grossit |
| 36 | 28.8 Mbps | 0.9936 | Ignorée car le gain est faible |
| 42 | 14.3 Mbps | 0.9900 | Convertie |

Pour réduire ce genre de vidéo, il faut augmenter `CQ`, ce qui baisse aussi la qualité de toutes les autres vidéos.

### Grands nombres de fichiers

| Élément | Résultat |
|---|---|
| Recherche de 23,100 vidéos sur un SSD local | 0.6 seconde |
| Recherche de 22,887 vidéos sur un montage crypt rclone | 8.9 secondes |
| Traitement des 23,100 vidéos sur un SSD local (toutes déjà en AV1) | 224 secondes |

## Limitations

### Risque de perte de données

- **Les pistes de sous-titres sont perdues.** Il en va de même pour la deuxième piste vidéo et les suivantes. N'utilisez pas le mode Y sur des fichiers qui en ont besoin.
- **La suppression en mode Y ne peut pas être annulée.** Elle utilise `del`, donc rien ne passe par la Corbeille.
- **Les résultats ne sont pas relus pour être vérifiés.** La réussite est évaluée uniquement d'après le code de sortie de ffmpeg et la taille du fichier. Si la vidéo est endommagée mais que ffmpeg signale une réussite, l'original est supprimé en mode Y.
- **La conversion en AV1 est une compression avec perte.** Compresser une vidéo déjà compressée ne rend jamais la qualité meilleure que celle de l'original.
- **Les vidéos 4:2:2 et 4:4:4 perdent de la résolution de couleur lorsqu'elles sont réduites à 4:2:0.** Utilisez le mode N pour les vidéos que vous prévoyez de monter ou d'étalonner.

### Où les décisions peuvent se tromper

- **L'estimation ne regarde que les 10 secondes du milieu.** Lors des tests, une vidéo estimée à 30% a en réalité donné 45%. Des vidéos qui auraient diminué peuvent être ignorées.
- **Les vidéos de moins de 1 minute ne sont pas vérifiées à l'avance.** La taille n'est comparée qu'après la conversion.
- **Si ffprobe ne peut pas lire un fichier, celui-ci est traité comme n'étant pas en AV1.** Un fichier déjà en AV1 peut être encodé de nouveau.

### Lecture et compatibilité

- Les appareils et lecteurs anciens ne peuvent pas lire l'AV1.
- avi, wmv et flv conservent leur extension, mais l'AV1 dans ces formats n'est pas une combinaison standard, et de nombreux lecteurs ne le liront pas.

### Noms de fichiers et dossiers

- Si les noms de résultats entrent en conflit, comme avec `a.mov` et `a.mp4`, le fichier traité en second est ignoré.
- Un `name.part.mp4` laissé après un arrêt est traité comme une vidéo normale à l'exécution suivante. Supprimez-le vous-même.
- Les jonctions et les dossiers de liens symboliques ne sont pas parcourus.

### Environnement

- **Les messages à l'écran sont en anglais.**
- **Il n'a été testé que sur Windows 11 en coréen.** Le fichier bat n'utilise que des caractères ASCII, il ne dépend donc pas de la langue du système. Son fonctionnement a été confirmé avec les pages de codes de console 437, 949 et 65001, mais il n'a pas été exécuté sur Windows dans d'autres langues.
- **N'écrasez pas un fichier bat utilisé par une fenêtre en cours d'exécution.** cmd lit le fichier petit à petit, donc une fenêtre en cours d'exécution peut exécuter les mauvaises lignes.
- L'encodage par CPU est beaucoup plus lent, environ 14 fps en 8K.
- Si ffmpeg n'inclut pas `libsvtav1`, le script ne peut pas passer au CPU et se termine par une erreur.

### Utilisation sur un montage rclone

- `--vfs-cache-mode writes` est obligatoire. Avec `off`, les mp4 et mkv ne peuvent pas être écrits et tous les fichiers échouent.
- En mode Y, **les originaux sont supprimés avant la fin de l'envoi.** Si l'envoi échoue, vous dépendez de la copie restée dans le cache, alors soyez prudent.
- Les fichiers en cours d'envoi ne sont pas retirés du cache, même au-delà de `--vfs-cache-max-age` et `--vfs-cache-max-size`, donc le lecteur du cache a besoin d'espace libre.
- Ces points ont été testés avec un remote crypt local. La version actuelle n'a été confirmée sur un vrai montage que jusqu'à la recherche des fichiers, et elle n'a pas été testée avec un stockage cloud.

### Non testé

- **L'encodage réel avec Intel QSV et AMD AMF n'a pas été essayé.** Ce matériel n'était pas disponible, seule l'analyse des options a donc été vérifiée. On ne sait pas non plus si la qualité correspond au CQ de NVENC.
- Cartes graphiques avec un seul moteur NVENC (seul le basculement a été vérifié, en simulant un échec du mode 2 moteurs)
- Les environnements sans NVENC ont été simulés en masquant la carte graphique. Il n'a pas été exécuté sur de vrais PC AMD ou Intel.
- La conservation des métadonnées VR (sphériques) et de Dolby Vision
- La conservation des données HDR avec l'encodage CPU
- Chemins de plus de 260 caractères

## Licence

[MIT](LICENSE)
