---
aliases: ["Proposition — Structure de données de la grille", "Structure de la grille", "Chunks de tuiles"]
tags: [ouvert, proposition, héritage-voxel, technique, à-trancher]
domaine: technique
statut: à-trancher
etape: 0
---

> [!todo] Proposition à valider
> Rédigée le 2026-08-26 pour remplacer l'héritage voxel. **Rien ici n'est une décision du GDD.**

**Le problème :** [[Décisions d'architecture]] spécifie des chunks cubiques 16×16×16 indexés `(x,y,z)` avec octrees de subdivision — contredit par [[Grille continue]] (chunk = 32×32 tuiles, tuile = « structure plate, lisible, sérialisable »). Il faut la structure de données réelle, y compris pour les étages de donjon et le format du diff de sauvegarde ([[Sauvegarde]]).

## La proposition

**Surface — chunks 32×32 tuiles indexés `(cx, cz)`.** Par tuile, quatre champs en SoA (PackedByteArray/PackedInt32Array, jamais d'Array de Variant — [[Optimisation — principes]] inchangé) :

```
height   : u8   (0-20, cf. 3.6)
ground   : u16  (id matériau de sol)
content  : u16  (0 = rien ; mur, arbre, filon, meuble, empreinte...)
c_data   : u16  (état/orientation du contenu)
→ ~7 o/tuile, chunk 32×32 ≈ 7 Ko. Chunks uniformes (mer, plaine nue)
  stockés comme constante — même optimisation que l'ancien G.2.
```

L'**occupant** (créature) n'est pas stocké dans la tuile : c'est un index runtime tuile→entité, reconstruit au chargement depuis `entities.json` — cohérent avec « instance ≠ définition » ([[Schéma créature]]).

**Donjons — des grilles bornées indépendantes**, adressées `(dungeon_id, floor)`, faites des **mêmes chunks 32×32**, générées paresseusement à l'accès de l'étage ([[Génération de donjon]] : déjà prévu). Plus de « volume de chunks sous la cellule » : un étage est une grille séparée, point. C'est ce que [[Grille continue]] annonce (« grilles séparées en étages discrets ») et ce qui rend [[Temporalités parallèles]] naturel (une horloge par donjon = une grille par donjon).

**Sauvegarde — le diff de [[Sauvegarde]] devient :**

```
chunks/cx_cz.bin           : liste (index_tuile u16, masque_champs u8, valeurs)
dungeons/{id}/floor_n.bin  : même format
```

Le principe `seed + liste des modifications` est inchangé. Plus d'octree sérialisé.

**Réseau —** une mutation est `(grid_id, index_tuile, champs)` ; RPC `place_tile`/`modify_tile` remplacent `place_block`/`destroy_block` ([[Réseau]]). Toujours des événements discrets, encore plus légers qu'avant.

**Ce qui disparaît partout :** la subdivision, les octrees, l'indexation `(x,y,z)`, le budget « 512 blocs subdivisés/chunk ».

## Ce qui reste à trancher

La taille exacte de `c_data` (suffit-il pour l'état d'une culture, d'une porte, d'un glyphe ?) ; si les glyphes/effets persistants de combat ([[Familles de capacités de la grille]]) vivent dans `content` ou dans une couche d'overlay séparée.

## Liens
- **Dépend de** : [[Héritage voxel — audit]], [[Grille continue]], [[Décisions d'architecture]]
- **Alimente** : [[Sauvegarde]], [[Réseau]], [[Génération de donjon]], [[Voxels — mémoire et meshing]]
- **Voir aussi** : [[Optimisation — principes]], [[Proposition — Budgets et critères de performance tactiques]]
