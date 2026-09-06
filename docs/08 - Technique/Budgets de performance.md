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

> [!note] 2026-09-06, 0 h 30 — l'échelle de la simulation, mesurée (`sonde_echelle.tscn`)
> 197 êtres chargés : 1,2 ms par tick du monde ; 2 000 êtres (résidents clonés) : 4,8 ms, sous le budget d'une image (12 ms), après que la faim, la météo et la vision ont cessé de balayer toutes les entités pour trouver le joueur (`Simulation.joueurs()`). Le poste restant : la recherche de la prochaine entité due, un balayage par pas. Détail et suite dans [[Modules de la simulation et le C++]].

> [!decision] 2026-09-06, 1 h 45 — le terrain par morceaux (suite du lag en ville)
> La couche `Terrain` redessinait **toute** la zone autour du joueur (41 × 41 tuiles) dès qu'il s'éloignait du centre de la passe ou qu'il **découvrait une tuile** — en ville, chaque pas découvre : c'était la saccade en marchant. Désormais le terrain est un ensemble de **morceaux de 8 × 8 tuiles** (`TerrainMorceau`, un nœud chacun, `z_index` = colonne + ligne du morceau, ce qui garde l'ordre de profondeur isométrique : deux morceaux de même z ne se recouvrent jamais). Un morceau ne se redessine que si une de ses tuiles change (`tile_changed`, avec ses voisines de bord) ou se découvre (les tuiles du champ de vue du joueur, quand le compte de découvertes bouge) ; les morceaux naissent et meurent avec la distance au joueur (`RAYON_VUE`), une nouvelle grille les refait tous. Les végétaux (billboards) suivent leur morceau. Mesure attendue : `draw.terrain` en pic passe de la zone entière à un ou deux morceaux.
>
> **Mesuré à 2 h 30** (capture `--ville --frames 400`, même cité de 202 habitants, machine chargée) : moyenne **16,6 → 12,3 à 14,9 ms** par image, pire **18 → 18 à 25** (la première image, qui dessine les 36 morceaux d'un coup) ; les morceaux ne se redessinent plus ensuite (`n.terrain` 36 sur 395 images, la simulation dit au client quelles tuiles viennent d'être découvertes : `Grille.decouvertes_recentes`) ; le paperdoll passe de 450 ms cumulées (267 dessins) à 47 à 86 ms (92 à 224 dessins) grâce aux pictogrammes. Les morceaux de 16 × 16 essayés d'abord coûtaient 12 ms chacun à redessiner et cachaient moins bien hors écran : 8 × 8 est le bon grain. Ce qui reste dans l'image (une dizaine de ms) est le rendu Godot lui-même des tuiles retenues et des êtres : la prochaine marche sera les sprites.

> [!decision] 2026-09-06, 2 h — les êtres lointains en pictogramme
> Un paperdoll complet coûte près de 2 ms à dessiner (segments, tenus, occulteurs) et un PNJ qui marche change d'orientation à chaque pas : en ville, deux cents habitants en mouvement, c'est un redessin permanent même avec la signature. Au-delà de `combat_rules.tempo.pictogramme_au_dela` tuiles du joueur (12 ; 0 pour désactiver), le paperdoll dessine un **pictogramme** — un corps et une tête à sa couleur de peau, un liseré rouge s'il est hostile — qui ne dépend ni de l'orientation ni de l'équipement : il ne se redessine qu'en franchissant le seuil. De près, rien ne change. Le seuil est un choix de regard autant que de budget : [[À juger — parcours de jeu]].

> [!note] 2026-09-06, 3 h 30 — la semaine d une ville chargée
> Sonde des villes (monde 9, 189 résidents, cinq cellules) : le passage de semaine coûtait 560 ms, dont 200 en humeurs et 44 en maisons — la détection de pièces inondait mille tuiles par porte côté rue, et chaque lit cherchait sa pièce dans chaque pièce. Après ([[Détection de pièces]], l extérieur d abord ; une table tuile → pièce par cellule) : 98 ms en humeurs, 33 en maisons. Le reste de la semaine est la production, les royaumes PNJ et les pas simulés en accéléré.

## Liens
- **Dépend de** : [[Décisions d'architecture]], [[Boucle de tick]]
- **Alimente** : [[Optimisation — principes]], [[Entités et pathfinding — performance]], [[Ordre de vérification]]
- **Voir aussi** : [[Décision — Budgets et critères de performance tactiques]], [[Décision — Structure de données de la grille]], [[Éclairage]], [[Génération procédurale — performance]], [[Simulation du monde — performance]], [[Réseau et sauvegarde — performance]], [[Risques majeurs]]
