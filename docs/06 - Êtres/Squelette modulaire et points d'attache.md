---
aliases: ["12.1", "12.1 Points d'attache", "Points d'attache", "Paperdoll", "Couleurs réservées", "9.1", "9.2"]
tags: [êtres, art, technique, décidé]
domaine: êtres
statut: décidé
etape: 1
---

> [!note] Adapté au pivot tactique
> Adapté au pivot : le pipeline d'import (marqueurs de couleurs réservées, points d'attache typés) s'applique aux **sprites** du paperdoll — même principe que l'import .vox d'origine.

Le pipeline d'assemblage : des points d'ancrage nommés encodés dans les sprites, une couleur réservée par type d'attache.

**Principe :** l'assemblage des parties du corps est un **paperdoll en couches de sprites** ([[Direction artistique]]) — chaque partie est un sprite avec ses **points d'ancrage nommés** (épaule, hanche, main, dos) et son ordre de superposition. Le pipeline modulaire est identique à celui prévu en voxel, en 2D :

- Sur chaque partie (torse, membre, tête...), l'artiste place des **points d'ancrage nommés** aux emplacements de connexion.
- **Une couleur réservée par type d'attache**, nomenclature **figée** (`data/reserved_colors.json`, section `anchors`) :

| Couleur | Attache | | Couleur | Attache |
|---|---|---|---|---|
| `#00FF7F` | bras / patte avant | | `#00BFFF` | jambe / patte arrière |
| `#FFFF00` | tête / cou | | `#FF00BF` | main (arme, outil) |
| `#FF7F00` | dos (cape, sac) | | `#7F00FF` | aile |
| `#FF0000` | queue / appendice | | `#00FFBF` | monture (selle) |

Aucune ne figure dans la palette des matériaux ([[Palette de couleurs des matériaux]]) ni dans les stand-in de recette (#00FF00, #FF00FF, #00FFFF, #FFFF00 — voir Décisions ci-dessous), **sauf `#FFFF00`** qui est partagé : les marqueurs d'attache vivent dans les sprites de **parties de corps**, les stand-in dans les sprites d'**objets et de prefabs** — deux pipelines d'import distincts, aucune collision possible. GameData le vérifie au boot.
- À l'import, le script détecte ces marqueurs, **les retire du modèle visible**, et enregistre leur position comme **point d'attache** dans la ressource.
- À l'assemblage d'une créature, le jeu aligne le point d'attache de chaque membre sur le point correspondant du torse — n'importe quelle partie de la bibliothèque se branche sur n'importe quelle autre, tant que les couleurs d'attache correspondent.
- **Orientation :** chaque ancrage porte une direction et un ordre de calque, pour que la partie s'oriente et se superpose correctement selon l'angle de vue isométrique (4 ou 8 directions).

**L'apparence vient des données ([[Apparence — données et équipement]]) :** la silhouette est déclarée par l'espèce, les couleurs et motifs viennent du **génome** ([[Loci — les dix types]]) — donc héritables et sélectionnables ([[Règle d'anneau]]) — et les pièces d'équipement s'attachent aux ancrages ci-dessous. Le même pipeline dessine un roi, un mouton et un papillon.

**Bénéfices dérivés :**
- Les templates de morphologie ([[Schéma unifié créature-PNJ]]) deviennent triviaux : un quadrupède est simplement un torse portant 4 attaches "patte" au lieu de 2 attaches bras + 2 attaches jambes.
- Les points d'attache servent aussi de **pivots d'animation** (rotation de l'épaule = rotation autour de l'attache du bras).
- Extensible aux **points d'équipement visibles** (l'arme équipée s'attache au marqueur main, la cape au marqueur dos...).

**Décisions :**
- **Templates de squelette au lancement : 4** — bipède/humanoïde, quadrupède, volant, amorphe (cohérent avec [[IA des créatures]]/[[Créatures]]). Extensible par données.
- **Bibliothèques de parties au lancement :** humanoïde 12 têtes / 8 torses / 8 bras / 8 jambes · quadrupède 6 têtes / 4 torses / 6 pattes · volant 4 têtes / 4 torses / 4 ailes · amorphe 6 corps entiers.
- **Règle de recrutement par type (défauts, surchargés par créature en [[Schéma créature]]) :** humanoïdes intelligents → `relation` · bêtes/animaux → `dressage` · PNJ uniques (rois, maîtres) → `dressage` à DD très élevé ou `quete` · certains → `jamais`.
- **Couleurs stand-in de matériaux figées (`data/reserved_colors.json`)** : #00FF00 (catégorie 1 de la recette), #FF00FF (cat. 2), #00FFFF (cat. 3), #FFFF00 (cat. 4) — remappées à la teinte du matériau réel au rendu. Les **ancrages** sont des métadonnées nommées, pas des couleurs. Aucune de ces valeurs n'existe dans la palette [[Palette de couleurs des matériaux]] (vérifié).

**Même technique réutilisée par :** les prefabs de donjon ([[Salles et connecteurs]]), les modèles d'objets ([[Schéma objet et recette]] : `vox_slots`), les blocs fonctionnels de véhicules ([[Véhicules]], marqueurs visibles).

**Import des parties ([[Décisions d'architecture]] — pipeline hérité du `.vox`, même principe appliqué aux sprites) :** script d'import custom qui détecte les pixels-marqueurs de couleurs réservées, les retire du sprite visible, et les exporte comme liste de points d'attache typés `{type, position, direction}`.

**Rendu partagé ([[Entités et pathfinding — performance]]) :** les parties sont des meshes **partagés** ; recolorisation par palette en shader (paramètre d'instance) — 100 villageois = ~6 meshes distincts en mémoire.

## Liens
- **Dépend de** : [[Schéma unifié créature-PNJ]], [[Direction artistique]], [[Décisions d'architecture]]
- **Alimente** : [[Schéma créature]], [[Monstres rares]], [[Salles et connecteurs]], [[Véhicules]]
- **Voir aussi** : [[Palette de couleurs des matériaux]], [[Entités et pathfinding — performance]], [[Créatures]], [[Schéma matériau]], [[Création de personnage]]
