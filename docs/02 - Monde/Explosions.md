---
aliases: ["A.11", "Annexe A.11", "Explosions"]
tags: [monde, combat, formule, décidé]
domaine: monde
statut: décidé
etape: 3
---

> [!note] Adapté au pivot tactique
> Adapté au pivot : formule exprimée en tuiles, clause de subdivision supprimée (texte d'origine : « chaque sous-bloc est testé individuellement »).

La formule de destruction par explosion.

```
Une explosion a : puissance P, rayon R (en blocs).
Pour chaque tuile dans R : détruite si durete_tuile < P * (1 - distance/R).
Les tuiles détruites droppent leur matériau avec 50 % de perte.
```

**Note :** la règle des 50 % de perte est réutilisée pour les épaves de véhicules ([[Véhicules]] : à 0 PV, épave récupérable à 50 % des matériaux).

**Note :** les objets ne s'usent pas ([[Pas de durabilité]]), mais **restent destructibles par des causes externes : explosions, etc.**

> [!success] Codé le 2026-08-28
> Objet **bombe** (établi : 2 houille brute + 1 lingot de métal ; `items/bombe.json` porte `bombe {puissance 40, rayon 2, retard_ticks 20, degats 3d6}`). Intention `lancer` (hotbar : une bombe du sac se sélectionne, le rayon se prévisualise, le clic lance) : portée 6 en ligne de vue, la bombe attend sur **son horloge** (`Simulation.bombes`, résolue dans `pas()` avant l'entité suivante — en mode action l'horloge saute à l'échéance). Explosion : pour chaque tuile à distance `d ≤ R` (Chebyshev), **détruite si `durete < P × (1 − d/R)`** (contenu `destructible`, dureté du matériau de la tuile, 10 par défaut), **50 % de chance de laisser une unité brute** ; chaque être dans le rayon subit `dégâts × (1 − d/R)` de type explosion (élément Feu), **friendly fire intégral** (le lanceur compris). Signal `explosion`. La Mèche (chaîne d'amorces) attend : une explosion ne déclenche pas encore les bombes voisines.

## Liens
- **Dépend de** : [[Matériaux — 13 stats]], [[Destruction du terrain]]
- **Alimente** : [[Véhicules]], [[Sorts cataclysmiques]]
- **Voir aussi** : [[Pas de durabilité]], [[Décision — Structure de données de la grille]]
