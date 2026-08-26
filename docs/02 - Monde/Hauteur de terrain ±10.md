---
aliases: ["3.6", "3.6 La hauteur de terrain", "Hauteur de terrain", "Dénivelé", "±10"]
tags: [monde, combat, structure, décidé]
domaine: monde
statut: décidé
etape: 0
---

La hauteur est quantifiée sur 21 niveaux et n'est pas un décor : c'est le système qui rend le placement tactique.

La hauteur est **quantifiée sur 21 niveaux** (0 à 20, référence à 10) — façon Final Fantasy Tactics / Disgaea. Ce n'est pas un décor, c'est un système :

| Différence | Effet |
|---|---|
| 0 | déplacement normal (3 ticks) |
| +1 | montée : 5 ticks |
| +2 | montée difficile : 8 ticks |
| +3 et plus | **infranchissable** (falaise) — sauf échelle, corde, sort |
| −1 / −2 | descente : 2 ticks |
| −3 et plus | chute autorisée, **dégâts** = (hauteur − 2) × 5 |

- **Ligne de vue bloquée par la hauteur** : un relief plus haut que la ligne tireur→cible coupe la vue — le tir à distance exige un dégagement, et la **Discrétion** gagne un support géométrique réel.
- **Zones de coup dérivées du dénivelé** ([[Zones de coup par dénivelé]]) : frapper d'en haut donne la tête, d'en bas les jambes.
- **Les fluides coulent** : l'eau remplit les creux, la lave descend. [[Eau et liquides]] se simplifie en 2D + hauteur au lieu d'un volume.
- **Destruction** : on peut **abaisser ou élever une tuile** (tranchée, talus), **détruire un mur ou un bâtiment** (la tuile redevient sol), **abattre un arbre**. La destruction reste tactiquement lisible — effondrer le pont, ouvrir une brèche, inonder la tranchée — sans permettre le tunnel arbitraire. *(Détail : [[Destruction du terrain]].)*

## Liens
- **Dépend de** : [[Grille continue]], [[Terrain spectaculaire]], [[Décisions fondatrices]]
- **Alimente** : [[Zones de coup par dénivelé]], [[Combat tactique sur grille]], [[Action-time à ticks]], [[Destruction du terrain]], [[Eau et liquides]], [[Sorts cataclysmiques]]
- **Voir aussi** : [[Piliers d'inspiration]], [[Direction artistique]], [[Familles de capacités de la grille]]
