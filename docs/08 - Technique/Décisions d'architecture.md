---
aliases: ["D.2", "Annexe D.2", "Décisions d'architecture", "GameData", "Import .vox", "Chunks cubiques"]
tags: [technique, architecture, décidé]
domaine: technique
statut: décidé
etape: 0
---

> [!note] Adapté au pivot tactique
> Les points voxel de D.2 (chunks cubiques 16³ indexés (x,y,z), octrees de subdivision, import .vox) sont retirés — archivés dans le GDD source. Leurs remplaçants : [[Décision — Structure de données de la grille]] et le pipeline de sprites de [[Squelette modulaire et points d'attache]].

Les décisions d'architecture Godot qu'on ne peut pas rattraper après coup.

- **Simulation à ticks (décision fondamentale, voir [[Action-time à ticks]])** : voir [[Simulation à ticks]].
- **Une seule scène `creature.tscn`** pour tout être vivant ([[Schéma unifié créature-PNJ]]) : elle se configure entièrement depuis un JSON de créature au spawn (parties de sprites, stats, IA). Ne jamais créer une scène par type de monstre.
- **GameData** charge tous les JSON au boot, valide les schémas (champs manquants → erreur claire en console), et expose des dictionnaires indexés par id. Hot-reload en debug (touche F5 recharge les données sans relancer) — crucial pour itérer sur le contenu.
- **EventBus** : les systèmes communiquent par signaux (`tile_destroyed`, `item_crafted`, `creature_killed`, `skill_xp_gained`...). Le système de quêtes écoute `creature_killed` sans que le combat connaisse les quêtes — c'est l'interaction inter-systèmes voulue en [[Data-driven design]]. Voir [[EventBus]].
- **Grille : chunks de 32×32 tuiles indexés `(cx, cz)`** ([[Grille continue]]) ; chaque tuile porte hauteur entière (0-20), matériau de sol, contenu, occupant — structure plate, sérialisable. Les étages de donjon sont des grilles bornées indépendantes faites des mêmes chunks. Détail des champs et de la mémoire : [[Décision — Structure de données de la grille]] ). Le streaming charge une bulle de chunks autour du joueur.
- **Import des parties graphiques :** script d'import custom qui lit les sprites sources et détecte les **pixels-marqueurs de couleurs réservées** ([[Squelette modulaire et points d'attache]]) : ils sont retirés du sprite visible et exportés comme liste de points d'attache typés `{type, position, direction}`. Le remapping des couleurs stand-in matériaux se fait dans un shader (palette 256 entrées passée en uniform/texture 256×1). Les couleurs réservées (attaches + stand-in matériaux) sont centralisées dans `data/palette_materiaux.json`.
- **Sauvegarde différentielle :** le monde n'est jamais sauvegardé entièrement ; seuls les chunks modifiés par rapport à la génération (diff) + les entités + l'état abstrait des claims sont écrits. Un chunk sauvegardé stocke `seed + liste des modifications`. Voir [[Sauvegarde]].
- **Réseau :** API haut niveau Godot (`MultiplayerAPI`, RPC). Le host est autoritaire. Les modifications de tuiles sont des RPC fiables (`place_tile`, `modify_tile`) ; positions des entités en unreliable à 10-20 Hz. Prévoir dès le début que toute mutation du monde passe par une fonction unique (facile à router en réseau plus tard, même si le multi arrive après le MVP). Voir [[Réseau]].
- **Temps :** horloge de jeu centrale dans WorldManager (jour/nuit, semaine in-game pour la régénération des cases sauvages, timers d'abstraction hors-site).

**Rappel ([[Grille continue]]) :** les donjons sont des grilles séparées en étages discrets — aucune exception d'architecture ([[Donjons — structure et intégration]]).

> [!success] Constaté le 2026-09-03 — les noms de signaux et de RPC ci-dessus sont des intentions
> `tile_destroyed` est codé sous `tile_changed`, `item_crafted` n'est pas un signal (appel direct des quêtes) — la liste réelle est dans [[EventBus]]. `place_tile` et `modify_tile` sont les RPC du réseau : **étape 11, non codés**, l'architecture host-autoritaire attend le jugement du solo.

## Liens
- **Dépend de** : [[Data-driven design]], [[Arborescence du projet]], [[Contraintes permanentes]]
- **Alimente** : [[Simulation à ticks]], [[EventBus]], [[Sauvegarde]], [[Réseau]], [[Décision — Structure de données de la grille]]
- **Voir aussi** : [[Modules de la simulation et le C++]], [[Schéma unifié créature-PNJ]], [[Squelette modulaire et points d'attache]], [[Grille continue]], [[Donjons — structure et intégration]], [[Optimisation — principes]], [[Ordre de construction]]
