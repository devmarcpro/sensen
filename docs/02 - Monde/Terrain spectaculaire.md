---
aliases: ["Terrain spectaculaire", "Altitude et reliefs", "Relief"]
tags: [monde, génération, décidé, héritage-voxel]
domaine: monde
statut: décidé
etape: 8
---

> [!warning] Héritage voxel
> Les chiffres (« 200-400 blocs », « 30-80 blocs ») et le bruit 3D de cavernes sont héritage : la hauteur tactique est bornée à **21 niveaux** ([[Hauteur de terrain ±10]]). Les techniques de composition du bruit survivent ; leur quantification est à décider — voir [[Héritage voxel — audit]].
> — Classement complet : [[Héritage voxel — audit]].

L'altitude n'est pas un bruit lissé : trois techniques de composition produisent des montagnes, des falaises et des côtes découpées. « Plat avec un peu de relief » est explicitement un anti-but.

Extrait de [[Unification macro-micro]] :

```
- Terrain 3D SPECTACULAIRE — l'altitude n'est pas un simple bruit
  lissé ("plat avec un peu de relief" est explicitement un anti-but) :
    altitude(x,z) = continentalité (bruit très basse fréquence :
      grandes masses émergées / mers)
      + relief modulé par une couche d'ÉROSION/PIC :
        * ridged noise (crêtes) → CHAÎNES DE MONTAGNES massives,
          arêtes vives, pics à 200-400 blocs au-dessus des plaines
        * domain warping (le bruit déforme ses propres coordonnées)
          → côtes découpées, vallées sinueuses, formes organiques
        * terrasses conditionnelles (quantification locale de
          l'altitude là où la couche sismique est forte) → FALAISES
          verticales de 30-80 blocs, mesas, canyons
      + bassins : les minima locaux larges sous le niveau d'eau
        régional → GRANDS LACS (remplis à la génération, sources
        E.22) ; les fleuves suivent le gradient entre lacs et mer.
    Formations rares (hash déterministe, façon POI) : arches
    naturelles, pitons isolés, cratères, gorges — assemblées par
    modificateurs de terrain paramétriques, pas de prefabs.
  Un bruit 3D de cavernes (densité) creuse en dessous ; les strates
  de matériaux suivent la profondeur + le biome de surface + les
  couches dédiées (ressources) pour les filons.
```

**Contrainte de performance ([[Génération procédurale — performance]]) :** le terrain spectaculaire reste du bruit par colonne — même coût que du terrain plat, seule la composition des couches change. Le domain warping double les évaluations de bruit sur x/z : rester à **1 niveau de warp** (pas de warp imbriqué).

**Conséquence tactique :** ce relief est directement lu par [[Hauteur de terrain ±10]] — les falaises deviennent infranchissables, les surplombs coupent la ligne de vue, et les zones de coup dérivent du dénivelé ([[Zones de coup par dénivelé]]).

## Liens
- **Dépend de** : [[Unification macro-micro]], [[Catalogue des couches de bruit]]
- **Alimente** : [[Hauteur de terrain ±10]], [[Eau et liquides]], [[Stratification verticale]]
- **Voir aussi** : [[Génération procédurale — performance]], [[Zones de coup par dénivelé]]
