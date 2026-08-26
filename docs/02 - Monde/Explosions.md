---
aliases: ["A.11", "Annexe A.11", "Explosions"]
tags: [monde, combat, formule, décidé, héritage-voxel]
domaine: monde
statut: décidé
etape: 3
---

> [!warning] Héritage voxel
> La clause « la subdivision est respectée : chaque sous-bloc est testé » est héritage — plus de subdivision. Rayon en tuiles + seuil de dureté + drop à 50 % suffisent sur la grille.
> — Classement complet : [[Héritage voxel — audit]].

La formule de destruction par explosion.

```
Une explosion a : puissance P, rayon R (en blocs).
Pour chaque bloc dans R : détruit si durete_bloc < P * (1 - distance/R).
La subdivision est respectée : chaque sous-bloc est testé individuellement
(un bloc 16px non subdivisé est testé une fois ; des sous-blocs 4px sont
testés chacun). Les blocs détruits droppent leur matériau avec 50 % de perte.
```

**Note :** la règle des 50 % de perte est réutilisée pour les épaves de véhicules ([[Véhicules]] : à 0 PV, épave récupérable à 50 % des matériaux).

**Note :** les objets ne s'usent pas ([[Pas de durabilité]]), mais **restent destructibles par des causes externes : explosions, etc.**

## Liens
- **Dépend de** : [[Matériaux — 13 stats]], [[Destruction du terrain]]
- **Alimente** : [[Véhicules]], [[Sorts cataclysmiques]]
- **Voir aussi** : [[Pas de durabilité]], [[Voxels — mémoire et meshing]]
