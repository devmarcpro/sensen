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

## Liens
- **Dépend de** : [[Matériaux — 13 stats]], [[Destruction du terrain]]
- **Alimente** : [[Véhicules]], [[Sorts cataclysmiques]]
- **Voir aussi** : [[Pas de durabilité]], [[Décision — Structure de données de la grille]]
