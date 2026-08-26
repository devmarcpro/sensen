---
aliases: ["Proposition — Sculpture en pixel art", "Sculpture pixel art", "Périmètres de sculpture"]
tags: [ouvert, proposition, héritage-voxel, objets, à-trancher]
domaine: objets
statut: à-trancher
etape: 6
---

> [!todo] Proposition à valider
> Rédigée le 2026-08-26 pour remplacer l'héritage voxel. **Rien ici n'est une décision du GDD.**

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

## Ce qui reste à trancher

La résolution des véhicules (96×64 suffit-il pour un voilier lisible ?) ; si une seconde vue (profil/face) est offerte pour les objets tenus en main ; l'outillage de l'éditeur (symétrie, pipette, remplissage).

## Liens
- **Dépend de** : [[Héritage voxel — audit]], [[Éditeur de sculpture]], [[Tables de sculpture]], [[Direction artistique]]
- **Alimente** : [[Véhicules]], [[Schéma objet et recette]], [[Stats d'un objet crafté]]
- **Voir aussi** : [[Palette de couleurs des matériaux]], [[Squelette modulaire et points d'attache]]
