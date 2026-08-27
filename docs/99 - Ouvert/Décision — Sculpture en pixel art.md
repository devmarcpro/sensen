---
aliases: ["Décision — Sculpture en pixel art", "Proposition — Sculpture en pixel art", "Sculpture pixel art", "Périmètres de sculpture"]
tags: [ouvert, proposition, héritage-voxel, objets, décidé]
domaine: objets
statut: décidé
etape: 6
---
> [!success] Abandonné le 2026-08-28 — instruction du designer
> « On abandonne complètement les tables de sculpture. » Cette note est conservée comme trace ; **rien de ce qu'elle décrit ne sera codé** : ni tables, ni éditeur, ni modèles sculptés, ni objets nommés par le joueur. Les objets viennent uniquement des recettes ([[Craft compositionnel]], craft simple) et du loot. La pondération des stats d'un objet est celle des composants et des recettes, jamais un comptage de pixels. Les accès par rang de guilde prévus ici disparaissent avec elles ([[Halls de guilde]], [[Quêtes et guildes]]).


> [!success] Décidé le 2026-08-26
> Rédigée pour remplacer l'héritage voxel, **validée sur délégation du designer** (« tout doit être rédigé et décidé avant production »). Le code s'appuie dessus ; révisable comme toute décision.

**Le problème :** [[Éditeur de sculpture]] décrit un mini-espace **voxel** (périmètres 16³ → 64×64×96, subdivision, ghost 3D), mais [[Construction cadrée]] et [[Tables de sculpture]] passent la sculpture en **pixel art paramétrique**. Il faut les périmètres et le pipeline 2D.

## La proposition

**Périmètres par table (en pixels) — transposition directe des volumes en plans :**

```
items      : 16×16      armes      : 16×48      meubles    : 32×32
blocs      : 16×16      structures : 64×64      véhicules  : 96×64
```

**Le pipeline :**
- **1 pixel = 1 unité de matériau**, débitée de l'inventaire en temps réel (rendue si effacée) — le principe d'E.9 inchangé.
- Le pixel s'affiche à la **couleur réelle du matériau** ([[Palette de couleurs des matériaux]]), avec son bruit généré en shader par pixel — pas de remapping nécessaire pendant la sculpture, comme avant.
- **Stats = comptage de pixels par matériau** ([[Stats d'un objet crafté]] : moyenne pondérée, formule inchangée) × qualité ([[Qualité d'artisanat]]). La forme reste cosmétique.
- **Rendu en jeu :** le modèle est un **billboard** — une vue isométrique de référence, déclinée par miroir horizontal pour l'orientation. Pas de 8 directions à dessiner : cohérent avec [[Direction artistique]] (peu d'animation, beaucoup de feedback d'interface).
- **Blocs fonctionnels des véhicules ([[Véhicules]]) :** des **pixels-marqueurs typés**, mêmes couleurs réservées que les points d'attache ([[Squelette modulaire et points d'attache]], `data/reserved_colors.json`) — siège, gouvernail, mât, roues, coffres. La validation vérifie les requis, comme avant.
- Validation → sprite + `stat_weights` + entrée d'objet ([[Schéma objet et recette]]) dans le profil joueur ; partage vers le catalogue de groupe sur action explicite (inchangé).

## Ce que ça préserve

Tout le contrat de [[Tables de sculpture]] : la sculpture optionnelle, le déblocage par rang de guilde, la qualité standard, le modèle réutilisable et nommé, le partage manuel explicite.

## Les derniers points, fixés

- **Véhicules : 128×96** (au lieu de 96×64) — un voilier avec mât, voile et coque a besoin de la hauteur ; c'est la seule table où la lisibilité l'exige.
- **Une seule vue par modèle.** Pas de seconde vue : l'orientation se fait par **miroir horizontal**, et les objets tenus en main s'attachent au marqueur main du paperdoll ([[Squelette modulaire et points d'attache]]) — le sprite est le même vu de chaque côté. Cohérent avec *peu d'animation, beaucoup de feedback d'interface* ([[Direction artistique]]).
- **Outillage de l'éditeur (v1)** : crayon, gomme, **pipette**, **pot de remplissage**, **symétrie verticale** (bascule), grille et aperçu à l'échelle du jeu. Pas de calques, pas de sélection rectangulaire — ce n'est pas un logiciel de dessin, c'est un éditeur de pièces de jeu.

## Liens
- **Dépend de** : [[Héritage voxel — audit]], [[Éditeur de sculpture]], [[Tables de sculpture]], [[Direction artistique]]
- **Alimente** : [[Véhicules]], [[Schéma objet et recette]], [[Stats d'un objet crafté]]
- **Voir aussi** : [[Palette de couleurs des matériaux]], [[Squelette modulaire et points d'attache]]
