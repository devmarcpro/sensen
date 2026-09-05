---
aliases: ["E.14", "Annexe E.14", "Budgets de performance", "Cibles de performance"]
tags: [technique, performance, décidé]
domaine: technique
statut: décidé
etape: 0
---

> [!note] Adapté au pivot tactique
> Les chiffres voxel (meshing < 4 ms/chunk, 8 Ko/chunk 16³) sont retirés — archivés dans le GDD source. Les budgets de rendu tuiles + billboards proposés : [[Décision — Budgets et critères de performance tactiques]].

Les cibles chiffrées de performance.

**Budgets confirmés (indépendants du pivot) :**
- **Tick complet : < 8 ms** (marge sur les 100 ms du tick).
- **Entités actives simultanées par zone : ~64.**
- Rayon de chargement : **8 chunks** autour du joueur par défaut.

**Budgets du rendu tactique ([[Décision — Budgets et critères de performance tactiques]]) :** 60 fps à rayon 8 chunks de tuiles ; mutation de tuile < 1 ms de re-render local, jamais de frame > 16 ms ; 200 billboards paperdoll animés sans chute de frame ; chunk généré < 2 ms en thread ; étage de donjon < 100 ms ; mémoire chunk 32×32 ≈ 7 Ko.

Si un chemin chaud GDScript est trop lent : passer cette partie (et elle seule) en GDExtension/Rust — **décision au profilage, pas avant** ([[Optimisation — principes]]).

La stratégie d'optimisation complète, système par système, est consolidée en **Annexe G** ([[Optimisation — principes]] et suivantes), **qui fait autorité en cas de divergence**.

**Critères de validation par étape :** [[Ordre de vérification]].

> [!success] Codé le 2026-08-31 — le tick sous les 8 ms, mesuré
> `test_budgets` mesure le pas de simulation (< 8 ms), la génération d'étage, d'objet à affixes et le recalcul de stats. Les budgets de rendu se lisent avec `capture.tscn --disable-vsync` (moyenne et pire image imprimées).

> [!important] 2026-09-05, 21 h — « le jeu lag énormément en ville » (designer), mesuré et allégé
> Le designer propose de réécrire du code en C++ ; sa règle du dépôt dit « pas de GDExtension » ([[Contraintes permanentes]], `AGENT.md`) — c'est à lui de la lever, et avant cela il fallait savoir CE QUI coûte. Mesure : `capture.tscn -- --ville --frames 400` imprime la moyenne et le pire d'une image, et `main.chrono` (le client chronomètre chaque étape de l'image : le pas de simulation, les nœuds, le texte, la minimap, chaque dessin). Dans une cité de 247 habitants (graine 21) : **25,1 ms par image, pire 83 ms** — dont 3,9 ms à redessiner **tous** les paperdolls à chaque image, 3,2 ms de HUD redessiné à chaque image pour deux cents êtres, 4 ms de texte et de minimap vingt fois par seconde, et presque rien de simulation (le pas du monde : 0,01 ms). Après : le paperdoll ne se redessine que si sa signature change (orientation, action, équipement, apparence — relue une image sur quatre, en quinconce), le HUD ne dessine que les êtres à l'écran et une image sur deux, le texte et la minimap sept fois par seconde → **16,6 ms par image, pire 18 ms** sur la même cité. Le reste est le rendu de Godot lui-même (deux cent trente paperdolls dessinés en commandes de canvas, le terrain en polygones) : c'est le plancher en GDScript, et le vrai gain suivant est de dessiner le terrain par cellule (un nœud par cellule, redessiné seulement quand elle change) et les êtres lointains en un seul pictogramme. Consigné dans [[À juger — parcours de jeu]].
> Le second problème vu par le designer, « les PNJ se sentent obligés de bouger constamment » : deux causes — une partie commençait le Nouvel An (toute la ville convergeait vers la place, et deux cents habitants visaient des coins pris : ils piétinaient) ; une partie commence désormais le 3 du Rat (`calendrier.jour_depart`), et un PNJ à un pas de sa cible prise s'y tient (`_actions_candidates`, `_ia_pas_routine`).

## Liens
- **Dépend de** : [[Décisions d'architecture]], [[Boucle de tick]]
- **Alimente** : [[Optimisation — principes]], [[Entités et pathfinding — performance]], [[Ordre de vérification]]
- **Voir aussi** : [[Décision — Budgets et critères de performance tactiques]], [[Décision — Structure de données de la grille]], [[Éclairage]], [[Génération procédurale — performance]], [[Simulation du monde — performance]], [[Réseau et sauvegarde — performance]], [[Risques majeurs]]
