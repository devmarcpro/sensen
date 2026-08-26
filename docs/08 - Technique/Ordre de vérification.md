---
aliases: ["G.8", "Annexe G.8", "Ordre de vérification", "Critères de perf par étape"]
tags: [technique, performance, décidé]
domaine: technique
statut: décidé
etape: 0
---

Un critère de performance à valider avant de passer à l'étape suivante. Un critère raté = on optimise AVANT d'empiler le système suivant.

```
Chaque étape de D.3 a son critère de perf AVANT de passer à la
suivante (sur machine moyenne cible) :
  1-2. Génération+rendu : 60 fps en vol rapide, rayon 8 chunks.
  3.   Casser/poser : aucune frame > 16 ms sur mutation.
  4.   Subdivision : une façade de 64 blocs 4px meshée < 4 ms.
  6.   50 créatures actives : tick < 8 ms.
  8.   2 joueurs LAN : mutation visible < 100 ms chez l'autre.
Un critère raté = on optimise AVANT d'empiler le système suivant.
```

*(Les numéros renvoient à l'ordre de construction conseillé D.3 — voir [[Ordre de construction]].)*

**Principe parallèle ([[Contraintes permanentes]]) :** *une brique à la fois, chacune avec un critère de sortie formulé AVANT de commencer.*

## Liens
- **Dépend de** : [[Optimisation — principes]], [[Budgets de performance]], [[Ordre de construction]]
- **Alimente** : [[Ordre de construction]]
- **Voir aussi** : [[Contraintes permanentes]], [[Voxels — mémoire et meshing]], [[Génération procédurale — performance]], [[Entités et pathfinding — performance]], [[Réseau et sauvegarde — performance]]
