---
aliases: ["G.2", "Annexe G.2", "Voxels mémoire", "Meshing", "Subdivision", "LOD de distance"]
tags: [technique, performance, décidé]
domaine: technique
statut: décidé
etape: 0
---

Stockage compact, greedy meshing en thread, et le LOD de distance — la parade au coût du 1px.

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

**Gain de la direction tactique ([[Grille continue]]) :** plus de meshing volumétrique, plus de LOD 3D, plus de streaming en volume, plus de propagation de lumière en 3D. Le rendu est : tuiles instanciées teintées par matériau + billboards triés en profondeur.

**Transparence ([[Application des stats de matériau]]) :** `transparence >= 50` → passe de rendu séparée.

**Budget de subdivision et sculpture ([[Éditeur de sculpture]]) :** le garde-fou de 512 blocs subdivisés/chunk protège des méga-sculptures 1px.

## Liens
- **Dépend de** : [[Optimisation — principes]], [[Décisions d'architecture]], [[Budgets de performance]]
- **Alimente** : [[Éclairage]], [[Éditeur de sculpture]], [[Sauvegarde]]
- **Voir aussi** : [[Grille continue]], [[Application des stats de matériau]], [[Palette de couleurs des matériaux]], [[Explosions]], [[Ordre de vérification]]
