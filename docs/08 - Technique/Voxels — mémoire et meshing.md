---
aliases: ["G.2", "Annexe G.2", "Voxels mémoire", "Meshing", "Subdivision", "LOD de distance", "Rendu de la grille"]
tags: [technique, performance, héritage-voxel, à-trancher]
domaine: technique
statut: à-trancher
etape: 0
---

> [!warning] Référence historique
> Cette note est la stratégie mémoire/meshing du moteur **voxel abandonné** — conservée intégralement ci-dessous comme référence. [[Grille continue]] acte : « plus de meshing volumétrique, plus de LOD 3D, plus de streaming en volume » ; le rendu tactique est **tuiles instanciées teintées par matériau + billboards triés en profondeur**. Le remplacement (structure de tuiles, budgets) : [[Proposition — Structure de données de la grille]] et [[Proposition — Budgets et critères de performance tactiques]].

La stratégie voxel d'origine (G.2) — et ce qui s'en transpose à la grille.

## Ce qui se transpose à la grille tactique

- **Chunks uniformes stockés comme constante** (mer, plaine nue) — même optimisation, appliquée aux chunks de tuiles.
- **Cache LRU + éviction** : données gardées en cache, sérialisées si modifiées / jetées si vierges (regénérables par seed) — inchangé dans le principe.
- **Données compactes en PackedByteArray** — repris par [[Proposition — Structure de données de la grille]] (~7 o/tuile).
- **Textures de bruit jamais stockées** : le bruit par tuile est généré en shader depuis (position, id matériau, seed) — zéro mémoire, variation infinie gratuite ([[Palette de couleurs des matériaux]]).

## Ce qui disparaît

Le stockage 3D, les octrees, la subdivision et son budget de 512 blocs/chunk, le greedy meshing, la fusion de faces à travers les résolutions, le LOD de distance sur la subdivision — il n'y a plus de volume à mesher.

---

### Texte voxel d'origine (référence historique, G.2)

```
STOCKAGE — chunk 16³ : PackedByteArray de 2 octets/bloc (id matériau,
  0 = air) = 8 Ko. Chunks 100 % air ou 100 % même matériau : stockés
  comme constante (1 entrée), pas de tableau — la majorité du monde
  (ciel, sous-sol profond) ne coûte presque rien.
SUBDIVISION — octree par bloc subdivisé, structure séparée (dictionnaire
  chunk-local index_bloc → octree). GARDE-FOU : budget de subdivision
  par chunk (défaut : 512 blocs subdivisés/chunk, message clair au
  joueur si atteint) — évite qu'une méga-sculpture 1px fasse exploser
  mémoire et meshing. À 1px, un bloc = jusqu'à 4096 sous-voxels : le
  greedy meshing fusionne les sous-voxels de même matériau, et les
  faces coplanaires SONT fusionnées à travers les résolutions
  (un mur mixte 16px/4px ne génère pas de couture).
MESHING — greedy meshing par chunk, en thread, budget 2 chunks
  uploadés/frame max. Un seul matériau de surface Godot par chunk
  (atlas/array de "textures" générées) → 1 draw call/chunk opaque
  + 1 transparent (A.4.5).
TEXTURES DE BRUIT — jamais stockées par bloc : le bruit par voxel
  (9.x) est généré EN SHADER depuis (world_pos, id_matériau, seed) —
  zéro mémoire texture par bloc, variation infinie gratuite.
LOD DE DISTANCE (rendu) — au-delà de N chunks (défaut 4) : les blocs
  subdivisés sont rendus à la résolution 16px (couleur moyenne de
  l'octree, précalculée à la modification) ; au-delà de 8 chunks :
  chunks fusionnés 2x2x2 en meshes simplifiés. La subdivision fine
  n'est jamais meshée au loin — c'est LA parade au coût du 1px.
ÉVICTION — chunks hors rayon : mesh libéré immédiatement, données
  gardées en cache LRU (256 chunks), puis sérialisées si modifiées /
  jetées si vierges (regénérables par seed).
```

## Liens
- **Dépend de** : [[Optimisation — principes]], [[Décisions d'architecture]], [[Héritage voxel — audit]]
- **Alimente** : [[Proposition — Structure de données de la grille]], [[Proposition — Budgets et critères de performance tactiques]]
- **Voir aussi** : [[Grille continue]], [[Palette de couleurs des matériaux]], [[Sauvegarde]], [[Éclairage]]
