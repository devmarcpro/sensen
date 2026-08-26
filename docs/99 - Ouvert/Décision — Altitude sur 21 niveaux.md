---
aliases: ["Décision — Altitude sur 21 niveaux", "Proposition — Altitude sur 21 niveaux", "Altitude 21 niveaux", "Mapping altitude"]
tags: [ouvert, proposition, héritage-voxel, monde, décidé]
domaine: monde
statut: décidé
etape: 8
---

> [!success] Décidé le 2026-08-26
> Rédigée pour remplacer l'héritage voxel, **validée sur délégation du designer** (« tout doit être rédigé et décidé avant production »). Le code s'appuie dessus ; révisable comme toute décision.

**Le problème :** [[Unification macro-micro]] décrit une altitude continue voxel (« pics à 200-400 blocs », « falaises de 30-80 blocs », bruit 3D de cavernes), mais [[Hauteur de terrain ±10]] quantifie la hauteur sur **21 niveaux (0-20)**. Il faut décider comment le champ de bruit continu produit la hauteur de tuile.

## La proposition : double lecture du même bruit

Le même champ `altitude(x, z)` est lu à deux échelles, comme le reste de la génération ([[Unification macro-micro]]) :

**Échelle macro (carte du monde) — l'altitude absolue devient un label de cellule.**
`altitude(x,z)` continue classe chaque cellule : mer · littoral · plaine · colline · montagne · haute montagne. Ce label pilote : l'affichage de la carte, les biomes ([[Biomes — schéma]] : la condition `altitude` existe déjà), et le `mod_altitude` de la température ([[Météo]]) — proposition : **−3 °C par classe au-dessus de « plaine »** (à calibrer), au lieu de « −1/20 blocs ». Les « pics à 200-400 blocs » n'existent plus en tuiles : ce sont des cellules classées haute montagne.

**Échelle micro (grille) — la hauteur de tuile est un relief relatif au voisinage.**

```
h(tuile) = clamp(0, 20, 10 + round( (alt(x,z) − alt_lissée(x,z)) / échelle_relief(biome) ))

alt_lissée      = moyenne locale de alt sur un rayon ~64 tuiles
                  (continue → aucune couture entre cellules)
échelle_relief  = amplitude par biome : plaine ±2 · colline ±5
                  · montagne ±8-10 (utilise toute la plage 0-20)
```

Les **terrasses conditionnelles** (quantification locale là où la couche sismique est forte) survivent telles quelles : elles produisent les paliers Δ≥3 — les falaises infranchissables qui font le tactique. Le ridged noise et le domain warping survivent aussi : ils sculptent `alt` avant quantification.

**Ce que deviennent les éléments voxel :**
- **Cavernes** : supprimées (le bruit 3D disparaît) — le souterrain est déjà remplacé par les donjons ([[Décisions fondatrices]]).
- **Formations rares** : transposées en modificateurs de relief 2D — gorge = saignée h−6, piton = colonne h+8, cratère = bol h−4, arche = décor/contenu de tuile.
- **Lacs et fleuves** : minima locaux larges sous le niveau d'eau régional → tuiles d'eau ; les fleuves suivent le gradient de l'altitude **macro** entre lacs et mer.

## Ce que ça préserve

Le relief reste spectaculaire *à l'échelle qui compte* : une cellule de montagne utilise toute l'amplitude 0-20 avec de nombreux Δ infranchissables, des cols, des terrasses — c'est exactement ce que le combat tactique consomme ([[Zones de coup par dénivelé]], ligne de vue). La continuité entre cellules est garantie par construction (`alt_lissée` est continue).

## Ce qui reste à calibrer

Le rayon de lissage (64 tuiles ?), les seuils de classe macro, les `échelle_relief` par biome, le barème de température.

## Liens
- **Dépend de** : [[Héritage voxel — audit]], [[Hauteur de terrain ±10]], [[Unification macro-micro]]
- **Alimente** : [[Terrain spectaculaire]], [[Météo]], [[Carte du monde]], [[Biomes — schéma]]
- **Voir aussi** : [[Génération procédurale — performance]], [[Catalogue des couches de bruit]]
