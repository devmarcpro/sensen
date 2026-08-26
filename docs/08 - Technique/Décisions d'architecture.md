---
aliases: ["D.2", "Annexe D.2", "Décisions d'architecture", "GameData", "Import .vox", "Chunks cubiques"]
tags: [technique, architecture, décidé]
domaine: technique
statut: décidé
etape: 0
---

Les huit décisions d'architecture Godot qu'on ne peut pas rattraper après coup.

- **Simulation à ticks (décision fondamentale, voir [[Action-time à ticks]])** : voir [[Simulation à ticks]].
- **Une seule scène `creature.tscn`** pour tout être vivant ([[Schéma unifié créature-PNJ]]) : elle se configure entièrement depuis un JSON de créature au spawn (parties .vox, stats, IA). Ne jamais créer une scène par type de monstre.
- **GameData** charge tous les JSON au boot, valide les schémas (champs manquants → erreur claire en console), et expose des dictionnaires indexés par id. Hot-reload en debug (touche F5 recharge les données sans relancer) — crucial pour itérer sur le contenu.
- **EventBus** : les systèmes communiquent par signaux (`block_destroyed`, `item_crafted`, `creature_killed`, `skill_xp_gained`...). Le système de quêtes écoute `creature_killed` sans que le combat connaisse les quêtes — c'est l'interaction inter-systèmes voulue en [[Data-driven design]]. Voir [[EventBus]].
- **Voxels : chunks cubiques de 16×16×16 blocs, indexés en 3D `(x, y, z)` dès le premier jour** (jamais en `(x, z)` + pile fixe — coût quasi nul maintenant, retrofit pénible plus tard). La cellule-monde de 128×128 = 8×8 chunks horizontaux × 32 en hauteur par défaut. Le streaming charge une bulle de chunks autour du joueur ; la hauteur 512 est une borne de design que le streaming peut ignorer si un mode profondeur infinie est activé (voir [[Grille continue]]). Chaque bloc est soit plein (1 id matériau, 2 octets), soit un pointeur vers un octree de subdivision (structure séparée, seule une minorité de blocs sont subdivisés — **budget de 512 blocs subdivisés par chunk**, voir [[Voxels — mémoire et meshing]]). Meshing par greedy meshing, uniquement les faces visibles, avec **LOD de distance** : la subdivision fine n'est jamais meshée au loin.
- **Import .vox :** script d'import custom (EditorImportPlugin) qui lit le format .vox directement et produit une ressource `VoxModel` conservant `positions + index de couleur`, et détectant les **voxels-marqueurs de couleurs réservées** ([[Squelette modulaire et points d'attache]]) : ils sont retirés du mesh visible et exportés comme liste de points d'attache typés `{type, position, direction}`. Le remapping des couleurs stand-in matériaux se fait dans un shader (palette 256 entrées passée en uniform/texture 256×1). Les couleurs réservées (attaches + stand-in matériaux) sont centralisées dans `data/reserved_colors.json`.
- **Sauvegarde différentielle :** le monde n'est jamais sauvegardé entièrement ; seuls les chunks modifiés par rapport à la génération (diff) + les entités + l'état abstrait des claims sont écrits. Un chunk sauvegardé stocke `seed + liste des modifications`. Voir [[Sauvegarde]].
- **Réseau :** API haut niveau Godot (`MultiplayerAPI`, RPC). Le host est autoritaire. Les modifications voxel sont des RPC fiables (`place_block`, `destroy_block`) ; positions des entités en unreliable à 10-20 Hz. Prévoir dès le début que toute mutation du monde passe par une fonction unique (facile à router en réseau plus tard, même si le multi arrive après le MVP). Voir [[Réseau]].
- **Temps :** horloge de jeu centrale dans WorldManager (jour/nuit, semaine in-game pour la régénération des cases sauvages, timers d'abstraction hors-site).

**Rappel — pas de volume souterrain ([[Grille continue]]) :** les donjons occupent le volume de chunks sous/autour de la cellule ; *aucune exception d'architecture, D.2 s'applique tel quel* ([[Donjons — structure et intégration]]).

## Liens
- **Dépend de** : [[Data-driven design]], [[Arborescence du projet]], [[Contraintes permanentes]]
- **Alimente** : [[Simulation à ticks]], [[EventBus]], [[Sauvegarde]], [[Réseau]], [[Voxels — mémoire et meshing]]
- **Voir aussi** : [[Schéma unifié créature-PNJ]], [[Squelette modulaire et points d'attache]], [[Grille continue]], [[Donjons — structure et intégration]], [[Optimisation — principes]], [[Ordre de construction]]
