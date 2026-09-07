---
aliases: ["G.4", "Annexe G.4", "Génération performance", "FastNoiseLite"]
tags: [technique, performance, décidé]
domaine: technique
statut: décidé
etape: 8
---

> [!note] Adapté au pivot tactique
> Le « remplissage 3D » et le « bruit 3D de cavernes » sont retirés (archivés — GDD source, historique git) : plus de volume à remplir. L'échantillonnage par position survit tel quel : la génération tactique EST une heightmap.

Le terrain spectaculaire coûte le même prix que le terrain plat — à condition de rester à un niveau de domain warping.

```
FastNoiseLite (natif Godot, C++) pour toutes les couches — jamais de
bruit en GDScript. Le terrain spectaculaire (E.2 : ridged, domain
warping, terrasses) reste du bruit par position — même coût que du
terrain plat, seule la composition des couches change. Le domain
warping double les évaluations de bruit sur x/z : rester à 1 niveau
de warp (pas de warp imbriqué). Les 8 couches sont échantillonnées
UNE FOIS par tuile (x,z), mises en cache par chunk — la génération
tactique est une heightmap : hauteur (0-20), matériau de sol, contenu,
directement par tuile, sans remplissage volumique.
Génération complète en thread, par anneaux de priorité autour du
joueur. Les POI/villages (E.2) se génèrent à la première visite de
la cellule uniquement (hash déterministe).
```

**Génération de donjon paresseuse ([[Génération de donjon]]) :** génération en thread au premier accès à l'étage — un étage jamais atteint ne coûte rien.

**Royaumes paresseux ([[Génération des royaumes PNJ]]) :** un royaume « existe » en données dès que son secteur est interrogé, mais ses villes/PNJ ne sont instanciés qu'à l'approche du joueur. Un royaume jamais visité ne coûte rien.

**Quantification de la hauteur :** le mapping altitude continue → 21 niveaux est spécifié en [[Décision — Altitude sur 21 niveaux]] (le lissage local s'échantillonne aussi par tuile, cache par chunk).

> [!success] Codé le 2026-09-06, 14 h 20 — la cellule de surface, moitié par le noyau C++ (file 109)
> `sonde_perf_generation` mesure désormais une cellule de surface, étape par étape (`Surface.chrono`) : 68 ms médian, dont **30 ms** la première passe (les couches par bloc de quatre tuiles, puis le sol, la mer et le matériau de chaque tuile) et **29 ms** la troisième (un tirage par tuile de sol : arbre, plante, cueillette, rocher, filon). Les deux boucles de tuiles sont désormais dans le noyau (`SensenGrille.sol_cellule`, `vegetation_cellule`), transcrites de `Surface._sol_gd` et `_vegetation_gd` qui restent la référence ; le RNG de la cellule (`RandomNumberGenerator`) est le même objet, consommé dans le même ordre, donc le quartier de village qui vient après tire les mêmes dés. `test_noyau_cpp` compare treize cellules autour du camp : identiques (hauteurs, sol, sols, eau, arbres, plantes, cueillette, rochers, filons, murs, portes, meubles, biomes vus, village). Résultat : **68 → 31 ms** par cellule ; la végétation 29 → 1,6 ms. Ce qui reste, **23 ms**, c'est `couches_a` sur les 256 blocs — huit bruits natifs mais la tectonique en GDScript (continentalité, warp, plaques proches, suture, biome) à 85 µs le bloc : la prochaine transcription, avec le soin des `Vector2` en simple précision.

> [!success] Mesuré et corrigé le 2026-09-07, 7 h — le butin d'un étage de donjon : 63 → 32 ms (le chargement 125 → 93 ms à froid)
> La sonde d'étage disait « 54 ms de butin » sans dire où. Un chrono par étape (`SimObjets.chrono`, `Donjon.chrono`, comme `Surface.chrono`) l'a montré : ce n'était pas la génération de l'objet (12 ms pour 82 pièces) mais sa **composition**, 38 ms. Trois gaspillages, tous du même genre — refaire à chaque appel ce qui ne change jamais :
> - **Les recettes d'un composant** se cherchaient en balayant les deux cents fiches de `component_recipes`, à chaque emplacement de chaque objet : six mille balayages par étage. Table `composant → recettes`, bâtie une fois. 5,9 → 0,4 ms.
> - **Le pool de matières d'un composant** (les matières de toutes ses recettes, dédupliquées) se refaisait de même. Caché par (composant, catégories). 5,6 → 0,5 ms.
> - **Le tirage pondéré** parcourait le dictionnaire des poids **deux fois** (une pour le total, une pour tirer) et allouait trois fois son tableau de clés — deux cent quarante chaînes par tirage. Le total et les poids sont désormais rangés en tableaux compacts à la mise en cache ; la soustraction successive garde le MÊME ordre, donc le même matériau sort pour le même tirage. Et le palier d'une matière se lit dans une table, pas par deux recherches dans le catalogue. 18,9 → 9,6 ms.
> Ce qui reste : `objet.generer` (12 ms — les affixes, la rareté, le nom : de la règle de jeu), `comp.tirage` (9,6 — la pondération que le cache ne peut pas éviter quand le pool change), `comp.appliquer` (4,1). Et la géométrie de l'étage, 21,6 ms, dont la connexité (7,2) et les escaliers (8,0) — deux parcours de graphe, candidats au noyau C++ si le budget le redemande.

> [!success] Mesuré et corrigé le 2026-09-07, 8 h — la géométrie d'un étage : 21,6 → 12,2 ms (le chargement 125 → 79 ms à froid, 94 → 60 à chaud)
> Après le butin, ce qui restait d'un étage était deux parcours de graphe : la **connexité** (6,6 ms) et le choix de l'**escalier** (7,3 ms), tous deux des BFS sur les trois mille tuiles de sol. Ce que la mesure a appris, étape par étape :
> - **`pop_front()` n'était pas le coupable** : le remplacer par un curseur n'a rien gagné (6,9 au lieu de 7,2). Il fallait mesurer plus fin — un chrono autour du BFS lui-même a montré qu'il portait 6,5 des 6,6 ms.
> - **Le dictionnaire, oui** : `vu` et `dist` en dictionnaire, la file en `Vector2i`, et `e.sol.has(idx)` interrogé quatre fois par tuile. En tableaux compacts (un octet par tuile pour le vu, un int32 pour la distance, la file en index, le sol lu **une** fois), le parcours devient linéaire et sans hachage.
> - **Le piège qui a doublé le coût avant de le diviser** : écrire les quatre directions `[1, -1, 0, 0][k]` dans la boucle **alloue un tableau à chaque tuile visitée** — la première version « optimisée » était plus lente que l'originale (7,9 contre 6,6). Les quatre voisins déroulés à la main : 1,6 ms.
> - **L'ordre de visite est un résultat, pas un détail** : `_plus_proche_atteint` départage à égalité de distance par le premier rencontré. Le BFS rend donc sa file (l'ordre d'atteinte) en plus du tableau des tuiles vues — sans quoi les mêmes graines ne rendraient plus les mêmes étages.
> Preuve : `sonde_signature_etage` (nouvelle) imprime la signature de six étages (trois graines × deux profondeurs : sol, murs, entrée, escalier, pièces, coffres, spawns, et un hash de tout). Avant et après, les six hashs sont identiques. C'est l'outil à relancer avant de toucher à la génération de donjon.

> [!success] Mesuré et corrigé le 2026-09-07, 18 h — le plein d'un étage posé en bloc : `Grille.depuis_etage` 13,8 ms → **1,9 ms** — sans C++ (designer : « réécriture C++ et optimisation », redit)
> La marche suivante de la mesure était `Grille.depuis_etage` (13,8 ms des 79 d'un étage). Avant de la porter dans le noyau, lire ce qu'elle fait : pour chacune des ~3 500 tuiles pleines d'un étage, `poser_contenu` — qui relit le contenu d'avant (un dictionnaire, pour l'eau qu'un butin posé conserverait), cherche l'identifiant dans `contenu_ids`, écrit `contenu[i]` et **marque la tuile dans `modifies`** (un dictionnaire de 3 500 entrées). Or `modifies` signifie « modifiée **depuis la construction** » : à la construction, tout cela est du travail pour rien, et une grille neuve n'a pas d'eau à conserver.
> **Le remède est algorithmique, pas un langage** : les deux identifiants (`roche` pour le bord, `mur` pour le reste) sont résolus une fois (`Grille.id_contenu`, que `poser_contenu` utilise aussi désormais), et la boucle écrit `contenu[i]` directement — un `PackedInt32Array`, pas un dictionnaire. Les meubles, les portes et la lave, quelques tuiles, gardent `poser_contenu`. Le test de connexité de l'étage compare le tableau `contenu` de ce chemin à celui d'une pose tuile par tuile : identiques (`sonde_perf_etage` : 13,8 → 1,9 ms ; le chargement d'un étage à chaud 62 → 60 ms, le butin de ses coffres restant le gros morceau, 40 à 47 ms selon la charge de la machine). C'est la règle de la section 3 de [[Modules de la simulation et le C++]] : on ne porte en C++ qu'une boucle pure qui reste chère **après** qu'on a retiré ce qu'elle faisait pour rien.

## Liens
- **Dépend de** : [[Optimisation — principes]], [[Unification macro-micro]], [[Catalogue des couches de bruit]]
- **Alimente** : [[Terrain spectaculaire]], [[Génération de donjon]], [[Génération des royaumes PNJ]]
- **Voir aussi** : [[Décision — Altitude sur 21 niveaux]], [[Biomes — schéma]], [[Météo]], [[Budgets de performance]], [[Ordre de vérification]]
