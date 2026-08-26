---
aliases: ["12.1", "12.1 Points d'attache", "Points d'attache", "Paperdoll", "Couleurs réservées", "9.1", "9.2", "Rig humanoïde", "Segments"]
tags: [êtres, art, technique, décidé]
domaine: êtres
statut: décidé
etape: 1
---

> [!note] Adapté au pivot tactique
> Le pipeline d'import (marqueurs de couleurs réservées, points d'attache typés) s'applique aux **sprites** du paperdoll — même principe que l'import `.vox` d'origine.

Le pipeline d'assemblage : des points d'ancrage nommés encodés dans les sprites, une couleur réservée par type d'attache.

**Principe :** l'assemblage des parties du corps est un **paperdoll en couches de sprites** ([[Direction artistique]]) — chaque partie est un sprite avec ses **points d'ancrage nommés** et son ordre de superposition.

---

## Le rig humanoïde — 14 segments

> [!success] Décidé le 2026-08-26
> Remplace l'ancienne bibliothèque à 4 types de parties (tête / torse / bras / jambes). Le rig articulé permet l'animation par pivots **sans dessiner une seule frame**.

| Segment | Nombre | Note |
|---|---|---|
| tête | 1 | |
| **torse** | 1 | **torse et bassin fusionnés** — un seul sprite du cou aux hanches |
| bras haut | 2 | G / D |
| bras bas | 2 | G / D — avant-bras |
| **main** | 2 | G / D — segment propre ; c'est elle qui porte l'arme |
| jambe haut | 2 | G / D — cuisse |
| jambe bas | 2 | G / D — mollet |
| pied | 2 | G / D |

**Le rig EST la grille d'armure.** Les 5 slots d'armure ([[Équipement — 14 slots]]) sont déjà mappés sur les zones de coup ([[Zones de coup par dénivelé]]) et couvrent exactement ces segments :

| Slot d'armure | Segments peints | Zone de coup |
|---|---|---|
| Casque | tête | ×2.5 |
| Cuirasse | torse | ×1.0 |
| Brassards-gants | bras haut, bras bas, **main** | — |
| Jambières | jambe haut, jambe bas | ×0.8 |
| Bottes | pied | ×0.8 |

Conséquence : **l'équipement visible est gratuit**, et un coup à la tête peut s'afficher sur la tête.

## Les directions se font par superposition

**Une seule passe de sprites. Aucune direction n'est redessinée.** L'orientation est produite par trois données, jamais par de l'art supplémentaire :

1. **L'ordre de calque** — de face, les deux bras passent devant le torse ; de dos, derrière ; de profil, le bras proche devant et le bras loin derrière.
2. **Les décalages d'ancrage** — les épaules et les hanches se resserrent ou s'écartent selon l'angle, ce qui donne la rotation du buste.
3. **Le miroir horizontal** — W, NW et SW sont les miroirs de E, NE et SE.

```
data/rigs/humanoide.json
{
  "segments": [...],
  "facings": {
    "S":  { "ordre": [bras_D…, bras_G…, tête, torse, jambes…], "offsets": {…} },
    "SE": { … },  "E": { … },  "NE": { … },  "N": { … },
    "SW": { "miroir": "SE" }, "W": { "miroir": "E" }, "NW": { "miroir": "NE" }
  }
}
```

Ce sont **des données, pas des dessins** — cinq orientations à décrire, trois obtenues par miroir. Cohérent avec [[Direction artistique]] : *peu d'animation, beaucoup de feedback d'interface*.

> [!warning] La tête est le seul point où la superposition ne suffit pas
> Un bras ou une jambe se relit correctement sous n'importe quel angle ; **un visage, non** — une tête dessinée de trois quarts lit mal de dos. La parade la moins chère : **3 vues par tête** (face, profil, dos) au lieu d'une, sélectionnées par le `facing`. Ça porte la bibliothèque de 12 à 36 sprites de tête, et **aucun autre segment n'a besoin de cette exception**. À confirmer au premier essai visuel.

## Le coût en assets

**Bibliothèque humaine de base** — 8 types de sprites (le côté G/D vient du miroir) :

```
12 têtes (×3 vues = 36) + 8 torses + 8 bras haut + 8 bras bas
+ 8 mains + 8 jambes haut + 8 jambes bas + 8 pieds
≈ 92 sprites — une fois, pour TOUS les humains du jeu
```

**Armure — on ne dessine pas par objet, mais par construction.** [[Armure par zone et constructions]] a déjà décidé que les types d'armure n'existent pas comme étiquettes : ils émergent des **5 constructions** (Matelassé, Cuir, Mailles, Écailles, Plaque), *« la construction donne le profil, le matériau donne les chiffres »*. Donc, visuellement : **la construction est la forme, le matériau est la teinte**.

```
5 constructions × 8 segments ≈ 40 sprites
→ pour la TOTALITÉ de l'armure du jeu
```

Les centaines de variantes de matériau viennent du **remapping de palette en shader**, déjà en place ([[Palette de couleurs des matériaux]], [[Entités et pathfinding — performance]]). Une arme = un sprite, accroché à l'ancrage `prise`.

**Total de départ ≈ 130 sprites** pour le paperdoll humain complet et toute son armure.

## Les ancrages

Neuf types, avec un suffixe `_G` / `_D` plutôt qu'une couleur par côté :

| Ancrage | Relie | | Ancrage | Relie |
|---|---|---|---|---|
| `cou` | torse → tête | | `hanche` | torse → jambe haut |
| `épaule` | torse → bras haut | | `genou` | jambe haut → jambe bas |
| `coude` | bras haut → bras bas | | `cheville` | jambe bas → pied |
| `poignet` | bras bas → main | | `dos` | torse → cape, sac |
| `prise` | main → arme, outil | | | |

**Couleurs réservées** (`data/reserved_colors.json`, section `anchors`) :

| Couleur | Ancrage | | Couleur | Ancrage |
|---|---|---|---|---|
| `#FFFF00` | cou | | `#00FF7F` | épaule |
| `#00E07F` | coude | | `#00C07F` | poignet |
| `#FF00BF` | prise (arme, outil) | | `#00BFFF` | hanche |
| `#00A0FF` | genou | | `#0080FF` | cheville |
| `#FF7F00` | dos | | `#7F00FF` · `#FF0000` · `#00FFBF` | aile · queue · monture |

Aucune ne figure dans la palette des matériaux ([[Palette de couleurs des matériaux]]) ni dans les stand-in de recette (#00FF00, #FF00FF, #00FFFF, #FFFF00), **sauf `#FFFF00`** qui est partagé : les marqueurs d'attache vivent dans les sprites de **parties de corps**, les stand-in dans les sprites d'**objets et de prefabs** — deux pipelines d'import distincts, aucune collision possible. GameData le vérifie au boot.

**Règle de miroir :** on dessine **un seul côté**, l'autre est miré. Surcharge explicite possible pour l'asymétrique — une épaulière unique, le bras au bouclier.

---

## Le pipeline

- Sur chaque partie, l'artiste place des **pixels-marqueurs** aux emplacements de connexion.
- À l'import, le script détecte ces marqueurs, **les retire du sprite visible**, et enregistre leur position comme point d'attache dans la ressource.
- À l'assemblage, le jeu aligne l'ancrage de chaque segment sur le correspondant du parent — n'importe quelle partie de la bibliothèque se branche sur n'importe quelle autre, tant que les types d'ancrage correspondent.

**L'apparence vient des données ([[Apparence — données et équipement]]) :** la silhouette est déclarée par l'espèce, les couleurs et motifs viennent du **génome** ([[Loci — les dix types]]) — donc héritables et sélectionnables ([[Règle d'anneau]]) — et les pièces d'équipement s'attachent aux ancrages. Le même pipeline dessine un roi, un mouton et un papillon.

**Bénéfices dérivés :**
- Les templates de morphologie ([[Schéma unifié créature-PNJ]]) deviennent triviaux : un quadrupède est un torse portant 4 chaînes `épaule → coude → pied` au lieu de 2 bras + 2 jambes.
- Les ancrages servent aussi de **pivots d'animation** — marche, frappe et garde s'obtiennent en faisant tourner les segments autour de leurs articulations, **sans dessiner de frames**.
- Extensible aux **points d'équipement visibles** (l'arme à `prise`, la cape à `dos`).

**Décisions :**
- **Templates de squelette au lancement : 4** — bipède/humanoïde, quadrupède, volant, amorphe ([[IA des créatures]]/[[Créatures]]). Extensible par données.
- **Bibliothèques au lancement :** humanoïde = le rig 14 segments ci-dessus · quadrupède 6 têtes / 4 torses / 6 pattes · volant 4 têtes / 4 torses / 4 ailes · amorphe 6 corps entiers.
- **Règle de recrutement par type (défauts, surchargés en [[Schéma créature]]) :** humanoïdes intelligents → `relation` · bêtes/animaux → `dressage` · PNJ uniques → `dressage` à DD très élevé ou `quete` · certains → `jamais`.
- **Couleurs stand-in de matériaux figées** : #00FF00 (catégorie 1 de la recette), #FF00FF (cat. 2), #00FFFF (cat. 3), #FFFF00 (cat. 4) — remappées à la teinte du matériau réel au rendu.

**Même technique réutilisée par :** les prefabs de donjon ([[Salles et connecteurs]]), les modèles d'objets ([[Schéma objet et recette]]), les blocs fonctionnels de véhicules ([[Véhicules]]).

**Import des parties ([[Décisions d'architecture]]) :** script d'import custom qui détecte les pixels-marqueurs de couleurs réservées, les retire du sprite visible, et les exporte comme liste de points d'attache typés `{type, côté, position}`.

**Rendu partagé ([[Entités et pathfinding — performance]]) :** les parties sont des ressources **partagées** ; recolorisation par palette en shader (paramètre d'instance) — 100 villageois = ~8 jeux de parties distincts en mémoire.

## Liens
- **Dépend de** : [[Schéma unifié créature-PNJ]], [[Direction artistique]], [[Décisions d'architecture]]
- **Alimente** : [[Schéma créature]], [[Apparence — données et équipement]], [[Équipement — 14 slots]], [[Armure par zone et constructions]], [[Monstres rares]]
- **Voir aussi** : [[Palette de couleurs des matériaux]], [[Entités et pathfinding — performance]], [[Zones de coup par dénivelé]], [[Créatures]], [[Création de personnage]]
