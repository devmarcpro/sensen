---
aliases: ["Décision — Structure de données de la grille", "Proposition — Structure de données de la grille", "Structure de la grille", "Chunks de tuiles", "G.2", "Annexe G.2", "Voxels mémoire", "Meshing"]
tags: [ouvert, proposition, héritage-voxel, technique, décidé]
domaine: technique
statut: décidé
etape: 0
---

> [!success] Décidé le 2026-08-26
> Rédigée pour remplacer l'héritage voxel, **validée sur délégation du designer** (« tout doit être rédigé et décidé avant production »). Le code s'appuie dessus ; révisable comme toute décision.

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

## Les derniers points, fixés

- **`c_data` reste en u16** : il code l'état du contenu **persistant** (stade de croissance 0-15, orientation 0-3, ouvert/fermé, dégâts) — largement suffisant. Ce qui déborde d'un u16 n'a rien à faire dans la tuile.
- **Les glyphes et effets persistants de combat ne vivent PAS dans la tuile** : ils sont dans une **couche d'overlay runtime** `Dictionary[index_tuile] → [effets]`, propre à la grille courante. Raison : ils sont temporaires, portent une source (le lanceur), une durée en ticks et un vecteur élémentaire — et **ils ne doivent jamais être sauvegardés** ([[Sauvegarde]] : seuls les diffs de terrain persistent). Un combat qui se termine vide l'overlay.

## Liens
- **Dépend de** : [[Héritage voxel — audit]], [[Grille continue]], [[Décisions d'architecture]]
- **Alimente** : [[Sauvegarde]], [[Réseau]], [[Génération de donjon]]
- **Voir aussi** : [[Optimisation — principes]], [[Décision — Budgets et critères de performance tactiques]]
