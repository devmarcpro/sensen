---
aliases: ["Terrain spectaculaire", "Altitude et reliefs", "Relief"]
tags: [monde, génération, décidé]
domaine: monde
statut: décidé
etape: 8
---

> [!note] Adapté au pivot tactique
> Les chiffres voxel (« 200-400 blocs », « 30-80 blocs ») et le bruit 3D de cavernes sont retirés — archivés dans le GDD source. La quantification du relief sur 21 niveaux : [[Décision — Altitude sur 21 niveaux]].

Trois techniques de composition du bruit produisent montagnes, falaises et côtes découpées — quantifiées sur les 21 niveaux de la grille. « Plat avec un peu de relief » est explicitement un anti-but.

**Les techniques ([[Unification macro-micro]]) :**
- **Continentalité** (bruit très basse fréquence) : grandes masses émergées / mers.
- **Ridged noise** (crêtes) : chaînes de montagnes, arêtes vives.
- **Domain warping** (le bruit déforme ses propres coordonnées) : côtes découpées, vallées sinueuses, formes organiques.
- **Terrasses conditionnelles** (quantification locale là où la couche sismique est forte) : les paliers **Δ ≥ 3 infranchissables** — falaises, mesas, canyons.
- **Bassins** : minima locaux larges sous le niveau d'eau régional → grands lacs ; les fleuves suivent le gradient entre lacs et mer.
- **Formations rares** (hash déterministe, façon POI) : gorges (saignée h−6), pitons (colonne h+8), cratères (bol h−4), arches — modificateurs de relief 2D paramétriques, pas de prefabs.

**Quantification ([[Décision — Altitude sur 21 niveaux]]) :** la hauteur de tuile 0-20 dérive du champ continu par **relief relatif au voisinage** — une cellule de montagne utilise toute l'amplitude avec de nombreux Δ infranchissables ; l'altitude absolue devient un label macro de la cellule (classe mer → haute montagne).

**Contrainte de performance ([[Génération procédurale — performance]]) :** le terrain spectaculaire reste du bruit par position — même coût que du terrain plat, seule la composition des couches change. Le domain warping double les évaluations de bruit sur x/z : rester à **1 niveau de warp** (pas de warp imbriqué).

**Conséquence tactique :** ce relief est directement lu par [[Hauteur de terrain ±10]] — les falaises deviennent infranchissables, les surplombs coupent la ligne de vue, et les zones de coup dérivent du dénivelé ([[Zones de coup par dénivelé]]).

## Liens
- **Dépend de** : [[Unification macro-micro]], [[Catalogue des couches de bruit]], [[Décision — Altitude sur 21 niveaux]]
- **Alimente** : [[Hauteur de terrain ±10]], [[Eau et liquides]]
- **Voir aussi** : [[Génération procédurale — performance]], [[Zones de coup par dénivelé]], [[Décision — Minerais et strates après le pivot]]
