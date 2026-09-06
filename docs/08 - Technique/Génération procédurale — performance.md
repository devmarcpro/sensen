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

## Liens
- **Dépend de** : [[Optimisation — principes]], [[Unification macro-micro]], [[Catalogue des couches de bruit]]
- **Alimente** : [[Terrain spectaculaire]], [[Génération de donjon]], [[Génération des royaumes PNJ]]
- **Voir aussi** : [[Décision — Altitude sur 21 niveaux]], [[Biomes — schéma]], [[Météo]], [[Budgets de performance]], [[Ordre de vérification]]
